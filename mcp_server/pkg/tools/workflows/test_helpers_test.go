package workflows

import (
	"testing"

	"github.com/mark3labs/mcp-go/mcp"
)

func requireErrorText(t *testing.T, res *mcp.CallToolResult) string {
	t.Helper()
	if res == nil {
		t.Fatalf("expected tool result")
	}
	if !res.IsError {
		t.Fatalf("expected error result, got success")
	}
	if len(res.Content) == 0 {
		t.Fatalf("expected error content")
	}
	text, ok := res.Content[0].(mcp.TextContent)
	if !ok {
		t.Fatalf("expected text content, got %T", res.Content[0])
	}
	return text.Text
}

func toFail(t *testing.T, format string, args ...any) {
	t.Helper()
	t.Fatalf(format, args...)
}
