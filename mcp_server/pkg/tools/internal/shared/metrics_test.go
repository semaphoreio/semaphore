package shared

import "testing"

func TestNewToolMetricsWithOrg(t *testing.T) {
	t.Parallel()

	tm := NewToolMetrics("test_tool", "ABC-123 ")
	if tm == nil {
		t.Fatalf("expected metrics emitter")
	}

	if got, want := len(tm.tags), 1; got != want {
		t.Fatalf("expected %d tags, got %d", want, got)
	}
	if tm.tags[0] != "org_abc-123" {
		t.Fatalf("expected org tag to be %q, got %q", "org_abc-123", tm.tags[0])
	}
	if tm.base != "tools.test_tool" {
		t.Fatalf("expected base metric %q, got %q", "tools.test_tool", tm.base)
	}
}

func TestNewToolMetricsWithoutOrg(t *testing.T) {
	t.Parallel()

	tm := NewToolMetrics("test_tool", "")
	if tm == nil {
		t.Fatalf("expected metrics emitter")
	}

	if len(tm.tags) != 0 {
		t.Fatalf("expected no tags, got %d", len(tm.tags))
	}
	if tm.base != "tools.test_tool" {
		t.Fatalf("expected base metric %q, got %q", "tools.test_tool", tm.base)
	}
}

func TestNewToolMetricsWithoutName(t *testing.T) {
	t.Parallel()

	if tm := NewToolMetrics("", ""); tm != nil {
		t.Fatalf("expected nil metrics when tool name is empty")
	}
}
