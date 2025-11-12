package shared

import (
	"testing"
	"time"
)

func TestNewToolMetricsWithOrg(t *testing.T) {
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
	if tm := NewToolMetrics("", ""); tm != nil {
		t.Fatalf("expected nil metrics when tool name is empty")
	}
}

func TestToolMetricsIncrementCounters(t *testing.T) {
	tm := NewToolMetrics("test_tool", "Org-123")
	if tm == nil {
		t.Fatalf("expected metrics emitter")
	}

	orig := watchmanIncrementWithTags
	defer func() { watchmanIncrementWithTags = orig }()

	tests := []struct {
		name        string
		invoke      func(*ToolMetrics)
		wantMetric  string
		expectedTag string
	}{
		{
			name:        "total",
			invoke:      (*ToolMetrics).IncrementTotal,
			wantMetric:  "tools.test_tool.count_total",
			expectedTag: "org_org-123",
		},
		{
			name:        "success",
			invoke:      (*ToolMetrics).IncrementSuccess,
			wantMetric:  "tools.test_tool.count_passed",
			expectedTag: "org_org-123",
		},
		{
			name:        "failure",
			invoke:      (*ToolMetrics).IncrementFailure,
			wantMetric:  "tools.test_tool.count_failed",
			expectedTag: "org_org-123",
		},
	}

	for _, tt := range tests {
		called := 0
		watchmanIncrementWithTags = func(metric string, tags []string) error {
			called++
			if metric != tt.wantMetric {
				t.Fatalf("test %s: expected metric %q, got %q", tt.name, tt.wantMetric, metric)
			}
			if len(tags) != 1 || tags[0] != tt.expectedTag {
				t.Fatalf("test %s: expected tags [%s], got %v", tt.name, tt.expectedTag, tags)
			}
			return nil
		}

		tt.invoke(tm)

		if called != 1 {
			t.Fatalf("test %s: expected watchman call once, got %d", tt.name, called)
		}
	}
}

func TestToolMetricsTrackDuration(t *testing.T) {
	tm := NewToolMetrics("test_tool", "Org123")
	if tm == nil {
		t.Fatalf("expected metrics emitter")
	}

	start := time.Unix(0, 0)

	orig := watchmanBenchmarkWithTags
	defer func() { watchmanBenchmarkWithTags = orig }()

	called := 0
	watchmanBenchmarkWithTags = func(actualStart time.Time, name string, tags []string) error {
		called++
		if !actualStart.Equal(start) {
			t.Fatalf("expected start time %v, got %v", start, actualStart)
		}
		if name != "tools.test_tool.duration_ms" {
			t.Fatalf("expected metric name %q, got %q", "tools.test_tool.duration_ms", name)
		}
		if len(tags) != 1 || tags[0] != "org_org123" {
			t.Fatalf("expected tags [org_org123], got %v", tags)
		}
		return nil
	}

	tm.TrackDuration(start)

	if called != 1 {
		t.Fatalf("expected watchman benchmark to be called once, got %d", called)
	}
}
