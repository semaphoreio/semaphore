package main

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/mark3labs/mcp-go/mcp"
	"github.com/mark3labs/mcp-go/server"

	"github.com/semaphoreio/semaphore/mcp_server/pkg/logging"
)

const (
	testUserID = "6a1c0e2b-0000-4000-8000-000000000001"
	testOrgID  = "7b2d0e2b-0000-4000-8000-000000000002"
)

func captureLogs(t *testing.T) *bytes.Buffer {
	t.Helper()
	var buf bytes.Buffer
	logger := logging.Logger()
	previous := logger.Out
	logger.SetOutput(&buf)
	t.Cleanup(func() { logger.SetOutput(previous) })
	return &buf
}

func logLines(t *testing.T, buf *bytes.Buffer) []map[string]any {
	t.Helper()
	var lines []map[string]any
	for _, raw := range strings.Split(strings.TrimSpace(buf.String()), "\n") {
		if raw == "" {
			continue
		}
		var line map[string]any
		if err := json.Unmarshal([]byte(raw), &line); err != nil {
			t.Fatalf("log line is not JSON: %q: %v", raw, err)
		}
		lines = append(lines, line)
	}
	return lines
}

func callerHeaders() http.Header {
	headers := http.Header{}
	headers.Set("X-Semaphore-User-ID", testUserID)
	headers.Set("X-Forwarded-For", "203.0.113.7, 10.0.0.1")
	headers.Set("User-Agent", "claude-code/2.0")
	headers.Set("X-Request-Id", "req-123")
	return headers
}

func assertCallerFields(t *testing.T, line map[string]any, wantOrg bool) {
	t.Helper()
	want := map[string]string{
		"tool":          "jobs_logs",
		"userId":        testUserID,
		"clientIp":      "203.0.113.7",
		"forwardedFor":  "203.0.113.7, 10.0.0.1",
		"userAgent":     "claude-code/2.0",
		"httpRequestId": "req-123",
		"requestId":     "1",
	}
	if wantOrg {
		want["orgId"] = testOrgID
	}
	for key, value := range want {
		if line[key] != value {
			t.Fatalf("log field %q = %v, want %q (line: %v)", key, line[key], value, line)
		}
	}
}

func readOnlyToolRequest() *mcp.CallToolRequest {
	request := &mcp.CallToolRequest{Header: callerHeaders()}
	request.Params.Name = "jobs_logs"
	request.Params.Arguments = map[string]any{"organization_id": testOrgID, "job_id": "job-1"}
	return request
}

func TestToolCallLogsIdentifyTheCaller(t *testing.T) {
	buf := captureLogs(t)

	hooks := &server.Hooks{}
	configureHooks(hooks)

	request := readOnlyToolRequest()
	ctx := context.Background()
	for _, hook := range hooks.OnBeforeCallTool {
		hook(ctx, 1, request)
	}
	for _, hook := range hooks.OnAfterCallTool {
		hook(ctx, 1, request, mcp.NewToolResultText("ok"))
	}

	lines := logLines(t, buf)
	if len(lines) != 2 {
		t.Fatalf("expected 2 log lines, got %d: %s", len(lines), buf.String())
	}

	if lines[0]["msg"] != "tool call started" {
		t.Fatalf("unexpected first message: %v", lines[0]["msg"])
	}
	assertCallerFields(t, lines[0], true)

	if lines[1]["msg"] != "tool call completed successfully" {
		t.Fatalf("unexpected second message: %v", lines[1]["msg"])
	}
	assertCallerFields(t, lines[1], true)
}

func TestToolCallErrorLogIdentifiesTheCaller(t *testing.T) {
	buf := captureLogs(t)

	hooks := &server.Hooks{}
	configureHooks(hooks)

	for _, hook := range hooks.OnError {
		hook(context.Background(), 1, mcp.MethodToolsCall, readOnlyToolRequest(), errors.New("boom"))
	}

	lines := logLines(t, buf)
	if len(lines) != 1 || lines[0]["msg"] != "tool call failed" {
		t.Fatalf("expected one 'tool call failed' line, got: %s", buf.String())
	}
	assertCallerFields(t, lines[0], true)
}

func TestToolCallErrorLogWithoutRequest(t *testing.T) {
	buf := captureLogs(t)

	hooks := &server.Hooks{}
	configureHooks(hooks)

	for _, hook := range hooks.OnError {
		hook(context.Background(), 1, mcp.MethodToolsCall, nil, errors.New("boom"))
	}

	lines := logLines(t, buf)
	if len(lines) != 1 || lines[0]["msg"] != "tool call failed" {
		t.Fatalf("expected one 'tool call failed' line, got: %s", buf.String())
	}
	if _, ok := lines[0]["userId"]; ok {
		t.Fatalf("did not expect userId without a request: %v", lines[0])
	}
}

func TestStreamableRequestLogIdentifiesTheCaller(t *testing.T) {
	buf := captureLogs(t)

	handler := instrumentStreamableHandler(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
	}))

	req := httptest.NewRequest(http.MethodPost, "/mcp", strings.NewReader("{}"))
	req.Header = callerHeaders()
	handler.ServeHTTP(httptest.NewRecorder(), req)

	lines := logLines(t, buf)
	if len(lines) != 1 || lines[0]["msg"] != "streamable request received" {
		t.Fatalf("expected one 'streamable request received' line, got: %s", buf.String())
	}
	for key, value := range map[string]string{
		"userId":        testUserID,
		"clientIp":      "203.0.113.7",
		"forwardedFor":  "203.0.113.7, 10.0.0.1",
		"userAgent":     "claude-code/2.0",
		"httpRequestId": "req-123",
		"path":          "/mcp",
	} {
		if lines[0][key] != value {
			t.Fatalf("log field %q = %v, want %q (line: %v)", key, lines[0][key], value, lines[0])
		}
	}
}
