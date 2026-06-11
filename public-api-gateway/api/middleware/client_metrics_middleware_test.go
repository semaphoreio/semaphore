package middleware

import (
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"os"
	"strings"
	"testing"

	"github.com/grpc-ecosystem/grpc-gateway/v2/runtime"
)

func reqWith(headers map[string]string) *http.Request {
	r, _ := http.NewRequest(http.MethodGet, "/api/v1alpha/jobs", nil)
	for k, v := range headers {
		r.Header.Set(k, v)
	}
	return r
}

// captureEvent runs the middleware with a stub next that writes the given
// status, captures stdout, and returns the decoded event.
func captureEvent(t *testing.T, r *http.Request, status int) map[string]any {
	t.Helper()

	pr, pw, _ := os.Pipe()
	orig := os.Stdout
	os.Stdout = pw

	mw := ClientMetricsMiddleware()
	handler := mw(func(w http.ResponseWriter, _ *http.Request, _ map[string]string) {
		w.WriteHeader(status)
	})

	rec := httptest.NewRecorder()
	handler(rec, r, map[string]string{})

	pw.Close()
	os.Stdout = orig

	out, _ := io.ReadAll(pr)

	var event map[string]any
	if err := json.Unmarshal([]byte(strings.TrimSpace(string(out))), &event); err != nil {
		t.Fatalf("could not decode emitted JSON: %v\nraw: %q", err, out)
	}
	return event
}

func TestClientMetricsMiddlewareEmitsEvent(t *testing.T) {
	r := reqWith(map[string]string{
		"x-client-source":          "semai-cli",
		"x-client-command":         "pipeline-list",
		"x-client-version":         "1.4.0",
		"x-semaphore-org-username": "acme-inc",
	})
	event := captureEvent(t, r, http.StatusOK)

	if got := event["severity"]; got != "INFO" {
		t.Errorf("severity = %q, want INFO", got)
	}
	if got := event["message"]; got != "client_request" {
		t.Errorf("message = %q, want client_request", got)
	}
	if got := event["client_source"]; got != "semai-cli" {
		t.Errorf("client_source = %q, want semai-cli", got)
	}
	if got := event["client_command"]; got != "pipeline-list" {
		t.Errorf("client_command = %q, want pipeline-list", got)
	}
	if got := event["client_version"]; got != "1.4.0" {
		t.Errorf("client_version = %q, want 1.4.0", got)
	}
	if got := event["client_org"]; got != "acme-inc" {
		t.Errorf("client_org = %q, want acme-inc", got)
	}
	if got, ok := event["status"].(float64); !ok || int(got) != http.StatusOK {
		t.Errorf("status = %v, want %d", event["status"], http.StatusOK)
	}
	if _, ok := event["duration_ms"]; !ok {
		t.Error("duration_ms missing")
	}
	if _, present := event["client_trace"]; present {
		t.Error("client_trace must not be present in gateway events")
	}
}

func TestClientMetricsMiddlewareSourceAllowlist(t *testing.T) {
	cases := []struct {
		header string
		want   string
	}{
		{"semai-cli", "semai-cli"},
		{"semai-mcp", "semai-mcp"},
		{"evil", "api"},
		{"", "api"},
	}
	for _, c := range cases {
		r := reqWith(map[string]string{"x-client-source": c.header})
		event := captureEvent(t, r, http.StatusOK)
		if got := event["client_source"]; got != c.want {
			t.Errorf("source %q => %q, want %q", c.header, got, c.want)
		}
	}
}

func TestClientMetricsMiddlewareCommandSanitize(t *testing.T) {
	valid := reqWith(map[string]string{"x-client-command": "critical-path"})
	if event := captureEvent(t, valid, 200); event["client_command"] != "critical-path" {
		t.Errorf("critical-path should pass, got %q", event["client_command"])
	}

	invalid := reqWith(map[string]string{"x-client-command": "DROP TABLE; rm -rf"})
	if event := captureEvent(t, invalid, 200); event["client_command"] != "na" {
		t.Errorf("injection attempt should be na, got %q", event["client_command"])
	}

	absent := reqWith(nil)
	if event := captureEvent(t, absent, 200); event["client_command"] != "na" {
		t.Errorf("absent command should be na, got %q", event["client_command"])
	}
}

func TestClientMetricsMiddlewareOrgFallback(t *testing.T) {
	byName := reqWith(map[string]string{
		"x-semaphore-org-username": "acme-inc",
		"x-semaphore-org-id":       "1bdc0370-a347-4cd6-8a01-1228ae6c6c83",
	})
	if event := captureEvent(t, byName, 200); event["client_org"] != "acme-inc" {
		t.Errorf("username preferred, got %q", event["client_org"])
	}

	byId := reqWith(map[string]string{
		"x-semaphore-org-id": "1bdc0370-a347-4cd6-8a01-1228ae6c6c83",
	})
	if event := captureEvent(t, byId, 200); event["client_org"] != "1bdc0370-a347-4cd6-8a01-1228ae6c6c83" {
		t.Errorf("id fallback, got %q", event["client_org"])
	}

	absent := reqWith(nil)
	if event := captureEvent(t, absent, 200); event["client_org"] != "na" {
		t.Errorf("absent org should be na, got %q", event["client_org"])
	}
}

func TestClientMetricsMiddlewareStatus(t *testing.T) {
	r := reqWith(nil)
	event := captureEvent(t, r, http.StatusNotFound)
	if got, ok := event["status"].(float64); !ok || int(got) != http.StatusNotFound {
		t.Errorf("status = %v, want %d", event["status"], http.StatusNotFound)
	}
}

// Ensure the middleware still compiles with runtime.Middleware type.
var _ runtime.Middleware = ClientMetricsMiddleware()
