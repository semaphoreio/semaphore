package middleware

import (
	"net/http"
	"testing"
)

func reqWith(headers map[string]string) *http.Request {
	r, _ := http.NewRequest(http.MethodGet, "/api/v1alpha/jobs", nil)
	for k, v := range headers {
		r.Header.Set(k, v)
	}
	return r
}

func TestClientSource(t *testing.T) {
	if got := clientSource(reqWith(map[string]string{"x-client-source": "semai-cli"})); got != "semai-cli" {
		t.Errorf("semai-cli => %q", got)
	}
	if got := clientSource(reqWith(map[string]string{"x-client-source": "semai-mcp"})); got != "semai-mcp" {
		t.Errorf("semai-mcp => %q", got)
	}
	if got := clientSource(reqWith(map[string]string{"x-client-source": "evil"})); got != "api" {
		t.Errorf("unknown => %q, want api", got)
	}
	if got := clientSource(reqWith(nil)); got != "api" {
		t.Errorf("absent => %q, want api", got)
	}
}

func TestClientCommandAndVersion(t *testing.T) {
	if got := clientCommand(reqWith(map[string]string{"x-client-command": "pipeline_list"})); got != "pipeline_list" {
		t.Errorf("command => %q", got)
	}
	if got := clientCommand(reqWith(map[string]string{"x-client-command": "critical-path"})); got != "critical-path" {
		t.Errorf("hyphen command => %q, want critical-path", got)
	}
	if got := clientCommand(reqWith(map[string]string{"x-client-command": "DROP TABLE; rm -rf"})); got != "na" {
		t.Errorf("bad command => %q, want na", got)
	}
	// dots AND plus neutralised so they can't corrupt the carbon path
	if got := clientVersion(reqWith(map[string]string{"x-client-version": "1.4.0+b.5"})); got != "1_4_0_b_5" {
		t.Errorf("version => %q, want 1_4_0_b_5", got)
	}
	if got := clientVersion(reqWith(nil)); got != "na" {
		t.Errorf("absent version => %q, want na", got)
	}
}

func TestStatusLabel(t *testing.T) {
	cases := map[int]string{200: "ok", 204: "ok", 301: "ok", 404: "client_error", 503: "server_error", 0: "unknown"}
	for status, want := range cases {
		if got := statusLabel(status); got != want {
			t.Errorf("statusLabel(%d) = %q, want %q", status, got, want)
		}
	}
}

func TestOrgTag(t *testing.T) {
	if got := orgTag(reqWith(map[string]string{"x-semaphore-org-username": "acme-inc"})); got != "acme-inc" {
		t.Errorf("username => %q", got)
	}
	if got := orgTag(reqWith(map[string]string{"x-semaphore-org-id": "1bdc0370-a347-4cd6-8a01-1228ae6c6c83"})); got != "1bdc0370-a347-4cd6-8a01-1228ae6c6c83" {
		t.Errorf("id fallback => %q", got)
	}
	if got := orgTag(reqWith(nil)); got != "" {
		t.Errorf("absent => %q, want empty", got)
	}
}
