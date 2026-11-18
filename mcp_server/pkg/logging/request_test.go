package logging

import (
	"net/http"
	"testing"

	"github.com/sirupsen/logrus"
)

func TestClientIP(t *testing.T) {
	tests := []struct {
		name    string
		headers http.Header
		want    string
	}{
		{name: "nil headers", headers: nil, want: ""},
		{name: "no forwarding headers", headers: http.Header{}, want: ""},
		{
			name:    "first X-Forwarded-For entry wins",
			headers: http.Header{"X-Forwarded-For": {" 203.0.113.7 , 10.0.0.1"}, "X-Real-Ip": {"10.0.0.2"}},
			want:    "203.0.113.7",
		},
		{
			name:    "falls back to X-Real-Ip",
			headers: http.Header{"X-Real-Ip": {" 198.51.100.4 "}},
			want:    "198.51.100.4",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := ClientIP(tt.headers); got != tt.want {
				t.Fatalf("ClientIP() = %q, want %q", got, tt.want)
			}
		})
	}
}

func TestForwardedFor(t *testing.T) {
	tests := []struct {
		name    string
		headers http.Header
		want    string
	}{
		{name: "nil headers", headers: nil, want: ""},
		{name: "no header", headers: http.Header{}, want: ""},
		{
			name:    "single hop",
			headers: http.Header{"X-Forwarded-For": {"203.0.113.7"}},
			want:    "203.0.113.7",
		},
		{
			name:    "forged first entry keeps the hops added by the load balancer",
			headers: http.Header{"X-Forwarded-For": {"1.2.3.4,203.0.113.7 ,  10.0.0.1"}},
			want:    "1.2.3.4, 203.0.113.7, 10.0.0.1",
		},
		{
			name:    "repeated headers are merged in order and empty hops dropped",
			headers: http.Header{"X-Forwarded-For": {"1.2.3.4, ", "203.0.113.7", "10.0.0.1"}},
			want:    "1.2.3.4, 203.0.113.7, 10.0.0.1",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := ForwardedFor(tt.headers); got != tt.want {
				t.Fatalf("ForwardedFor() = %q, want %q", got, tt.want)
			}
		})
	}
}

func TestRequestFields(t *testing.T) {
	headers := http.Header{}
	headers.Set("X-Semaphore-User-ID", " 6A1C0E2B-0000-4000-8000-000000000001 ")
	headers.Set("X-Forwarded-For", "203.0.113.7, 10.0.0.1")
	headers.Set("User-Agent", "claude-code/2.0")
	headers.Set("X-Request-Id", "req-123")

	got := RequestFields(headers)
	want := logrus.Fields{
		"userId":        "6a1c0e2b-0000-4000-8000-000000000001",
		"clientIp":      "203.0.113.7",
		"forwardedFor":  "203.0.113.7, 10.0.0.1",
		"userAgent":     "claude-code/2.0",
		"httpRequestId": "req-123",
	}
	assertFields(t, got, want)
}

func TestRequestFieldsOmitsMissingValues(t *testing.T) {
	assertFields(t, RequestFields(nil), logrus.Fields{})
	assertFields(t, RequestFields(http.Header{}), logrus.Fields{})
}

func TestToolCallFields(t *testing.T) {
	headers := http.Header{}
	headers.Set("X-Semaphore-User-ID", "6a1c0e2b-0000-4000-8000-000000000001")

	tests := []struct {
		name      string
		arguments any
		want      logrus.Fields
	}{
		{
			name:      "organization_id argument is promoted",
			arguments: map[string]any{"organization_id": " 7B2D0E2B-0000-4000-8000-000000000002 ", "job_id": "x"},
			want: logrus.Fields{
				"userId": "6a1c0e2b-0000-4000-8000-000000000001",
				"orgId":  "7b2d0e2b-0000-4000-8000-000000000002",
			},
		},
		{
			name:      "no organization_id argument",
			arguments: map[string]any{"job_id": "x"},
			want:      logrus.Fields{"userId": "6a1c0e2b-0000-4000-8000-000000000001"},
		},
		{
			name:      "non-string organization_id is ignored",
			arguments: map[string]any{"organization_id": 42},
			want:      logrus.Fields{"userId": "6a1c0e2b-0000-4000-8000-000000000001"},
		},
		{
			name:      "non-map arguments",
			arguments: nil,
			want:      logrus.Fields{"userId": "6a1c0e2b-0000-4000-8000-000000000001"},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			assertFields(t, ToolCallFields(headers, tt.arguments), tt.want)
		})
	}
}

func assertFields(t *testing.T, got, want logrus.Fields) {
	t.Helper()
	if len(got) != len(want) {
		t.Fatalf("fields = %v, want %v", got, want)
	}
	for key, value := range want {
		if got[key] != value {
			t.Fatalf("fields[%q] = %v, want %v (all: %v)", key, got[key], value, got)
		}
	}
}
