package shared

import "testing"

func TestNewToolMetricsWithOrg(t *testing.T) {
	t.Parallel()

	tm := NewToolMetrics("tools.test_tool", "Test Tool", "ABC-123 ")
	if tm == nil {
		t.Fatalf("expected metrics emitter")
	}

	if got, want := len(tm.tags), 2; got != want {
		t.Fatalf("expected %d tags, got %d", want, got)
	}
	if tm.tags[0] != "tool_test_tool" {
		t.Fatalf("expected tool tag to be %q, got %q", "tool_test_tool", tm.tags[0])
	}
	if tm.tags[1] != "org_abc-123" {
		t.Fatalf("expected org tag to be %q, got %q", "org_abc-123", tm.tags[1])
	}
}

func TestNewToolMetricsWithoutOrg(t *testing.T) {
	t.Parallel()

	tm := NewToolMetrics("tools.test_tool", "Test Tool", "")
	if tm == nil {
		t.Fatalf("expected metrics emitter")
	}

	if got := tm.tags[0]; got != "tool_test_tool" {
		t.Fatalf("expected tool tag %q, got %q", "tool_test_tool", got)
	}
	if len(tm.tags) != 1 {
		t.Fatalf("expected only tool tag, got %d tags", len(tm.tags))
	}
}

func TestNewToolMetricsWithoutBase(t *testing.T) {
	t.Parallel()

	if tm := NewToolMetrics("", "any", ""); tm != nil {
		t.Fatalf("expected nil metrics when base metric name is empty")
	}
}
