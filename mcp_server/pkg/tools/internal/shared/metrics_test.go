package shared

import (
	"context"
	"fmt"
	"strings"
	"sync"
	"testing"
	"time"
)

type orgResolverFunc func(ctx context.Context, orgID string) (string, error)

func (f orgResolverFunc) Resolve(ctx context.Context, orgID string) (string, error) {
	return f(ctx, orgID)
}

func withTestOrgResolver(t *testing.T, resolver OrgNameResolver) {
	SetOrgNameResolver(resolver)
	t.Cleanup(func() {
		SetOrgNameResolver(nil)
	})
}

func TestNewToolMetricsWithOrgName(t *testing.T) {
	withTestOrgResolver(t, orgResolverFunc(func(ctx context.Context, orgID string) (string, error) {
		return "Acme Corp", nil
	}))

	tm := NewToolMetrics(context.Background(), "test_tool", "ABC-123 ")
	if tm == nil {
		t.Fatalf("expected metrics emitter")
	}

	if got, want := len(tm.tags), 1; got != want {
		t.Fatalf("expected %d tags, got %d", want, got)
	}
	if tm.tags[0] != "org_acme_corp" {
		t.Fatalf("expected org tag to be %q, got %q", "org_acme_corp", tm.tags[0])
	}
	if tm.base != "tools.test_tool" {
		t.Fatalf("expected base metric %q, got %q", "tools.test_tool", tm.base)
	}
}

func TestNewToolMetricsFallsBackToOrgID(t *testing.T) {
	withTestOrgResolver(t, orgResolverFunc(func(ctx context.Context, orgID string) (string, error) {
		return "", fmt.Errorf("resolver error")
	}))

	tm := NewToolMetrics(context.Background(), "test_tool", "ABC-123 ")
	if tm == nil {
		t.Fatalf("expected metrics emitter")
	}

	if len(tm.tags) != 1 || tm.tags[0] != "org_abc-123" {
		t.Fatalf("expected fallback tag org_abc-123, got %v", tm.tags)
	}
}

func TestNewToolMetricsWithoutOrg(t *testing.T) {
	tm := NewToolMetrics(context.Background(), "test_tool", "")
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
	if tm := NewToolMetrics(context.Background(), "", ""); tm != nil {
		t.Fatalf("expected nil metrics when tool name is empty")
	}
}

func TestToolMetricsIncrementCounters(t *testing.T) {
	withTestOrgResolver(t, orgResolverFunc(func(ctx context.Context, orgID string) (string, error) {
		return "Demo Org", nil
	}))

	tm := NewToolMetrics(context.Background(), "test_tool", "Org-123")
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
			expectedTag: "org_demo_org",
		},
		{
			name:        "success",
			invoke:      (*ToolMetrics).IncrementSuccess,
			wantMetric:  "tools.test_tool.count_passed",
			expectedTag: "org_demo_org",
		},
		{
			name:        "failure",
			invoke:      (*ToolMetrics).IncrementFailure,
			wantMetric:  "tools.test_tool.count_failed",
			expectedTag: "org_demo_org",
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
	withTestOrgResolver(t, orgResolverFunc(func(ctx context.Context, orgID string) (string, error) {
		return "Demo Org", nil
	}))

	tm := NewToolMetrics(context.Background(), "test_tool", "Org123")
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
		if len(tags) != 1 || tags[0] != "org_demo_org" {
			t.Fatalf("expected tags [org_demo_org], got %v", tags)
		}
		return nil
	}

	tm.TrackDuration(start)

	if called != 1 {
		t.Fatalf("expected watchman benchmark to be called once, got %d", called)
	}
}

func TestToolExecutionTrackerSuccess(t *testing.T) {
	withTestOrgResolver(t, orgResolverFunc(func(ctx context.Context, orgID string) (string, error) {
		return "Test Org", nil
	}))

	origInc := watchmanIncrementWithTags
	origBench := watchmanBenchmarkWithTags
	defer func() {
		watchmanIncrementWithTags = origInc
		watchmanBenchmarkWithTags = origBench
	}()

	totalCalled := 0
	successCalled := 0
	durationCalled := 0

	watchmanIncrementWithTags = func(metric string, tags []string) error {
		if strings.HasSuffix(metric, "count_total") {
			totalCalled++
		} else if strings.HasSuffix(metric, "count_passed") {
			successCalled++
		}
		return nil
	}

	watchmanBenchmarkWithTags = func(start time.Time, name string, tags []string) error {
		durationCalled++
		return nil
	}

	tracker := TrackToolExecution(context.Background(), "test_tool", "org-123")
	if tracker == nil {
		t.Fatal("expected non-nil tracker")
	}

	tracker.MarkSuccess()
	tracker.Cleanup()

	if totalCalled != 1 {
		t.Fatalf("expected total counter once, got %d", totalCalled)
	}
	if successCalled != 1 {
		t.Fatalf("expected success counter once, got %d", successCalled)
	}
	if durationCalled != 1 {
		t.Fatalf("expected duration tracking once, got %d", durationCalled)
	}
}

func TestToolExecutionTrackerFailure(t *testing.T) {
	withTestOrgResolver(t, orgResolverFunc(func(ctx context.Context, orgID string) (string, error) {
		return "Test Org", nil
	}))

	origInc := watchmanIncrementWithTags
	origBench := watchmanBenchmarkWithTags
	defer func() {
		watchmanIncrementWithTags = origInc
		watchmanBenchmarkWithTags = origBench
	}()

	totalCalled := 0
	failureCalled := 0
	successCalled := 0

	watchmanIncrementWithTags = func(metric string, tags []string) error {
		if strings.HasSuffix(metric, "count_total") {
			totalCalled++
		} else if strings.HasSuffix(metric, "count_failed") {
			failureCalled++
		} else if strings.HasSuffix(metric, "count_passed") {
			successCalled++
		}
		return nil
	}

	watchmanBenchmarkWithTags = func(start time.Time, name string, tags []string) error {
		return nil
	}

	tracker := TrackToolExecution(context.Background(), "test_tool", "org-123")
	// Don't call MarkSuccess - simulates failure
	tracker.Cleanup()

	if totalCalled != 1 {
		t.Fatalf("expected total counter once, got %d", totalCalled)
	}
	if failureCalled != 1 {
		t.Fatalf("expected failure counter once, got %d", failureCalled)
	}
	if successCalled != 0 {
		t.Fatalf("expected no success counter, got %d", successCalled)
	}
}

func TestToolExecutionTrackerNilSafety(t *testing.T) {
	var tracker *ToolExecutionTracker
	// Should not panic
	tracker.MarkSuccess()
	tracker.Cleanup()
}

// TestMetricsIntegrationWithWatchman verifies that metrics are properly emitted
// to Watchman when tools are executed. This is an integration test that validates
// the full metrics pipeline.
func TestMetricsIntegrationWithWatchman(t *testing.T) {
	withTestOrgResolver(t, orgResolverFunc(func(ctx context.Context, orgID string) (string, error) {
		return "Integration Test Org", nil
	}))

	origInc := watchmanIncrementWithTags
	origBench := watchmanBenchmarkWithTags
	defer func() {
		watchmanIncrementWithTags = origInc
		watchmanBenchmarkWithTags = origBench
	}()

	// Track all metrics emitted
	type metricCall struct {
		name string
		tags []string
	}
	var incrementCalls []metricCall
	var benchmarkCalls []metricCall
	var mu sync.Mutex

	watchmanIncrementWithTags = func(metric string, tags []string) error {
		mu.Lock()
		defer mu.Unlock()
		incrementCalls = append(incrementCalls, metricCall{
			name: metric,
			tags: append([]string(nil), tags...),
		})
		return nil
	}

	watchmanBenchmarkWithTags = func(start time.Time, name string, tags []string) error {
		mu.Lock()
		defer mu.Unlock()
		benchmarkCalls = append(benchmarkCalls, metricCall{
			name: name,
			tags: append([]string(nil), tags...),
		})
		return nil
	}

	// Simulate a successful tool execution
	ctx := context.Background()
	metrics := NewToolMetrics(ctx, "integration_test_tool", "org-abc123")
	if metrics == nil {
		t.Fatal("expected non-nil metrics")
	}

	metrics.IncrementTotal()
	time.Sleep(10 * time.Millisecond) // Simulate work
	metrics.TrackDuration(time.Now().Add(-10 * time.Millisecond))
	metrics.IncrementSuccess()

	// Verify metrics were emitted
	mu.Lock()
	defer mu.Unlock()

	if len(incrementCalls) != 2 {
		t.Fatalf("expected 2 increment calls (total, success), got %d", len(incrementCalls))
	}

	if len(benchmarkCalls) != 1 {
		t.Fatalf("expected 1 benchmark call (duration), got %d", len(benchmarkCalls))
	}

	// Verify total counter
	totalCall := incrementCalls[0]
	if !strings.Contains(totalCall.name, "integration_test_tool") {
		t.Errorf("expected tool name in metric, got %q", totalCall.name)
	}
	if !strings.HasSuffix(totalCall.name, "count_total") {
		t.Errorf("expected count_total suffix, got %q", totalCall.name)
	}
	if len(totalCall.tags) != 1 || !strings.Contains(totalCall.tags[0], "integration_test_org") {
		t.Errorf("expected org tag, got %v", totalCall.tags)
	}

	// Verify success counter
	successCall := incrementCalls[1]
	if !strings.HasSuffix(successCall.name, "count_passed") {
		t.Errorf("expected count_passed suffix, got %q", successCall.name)
	}

	// Verify duration tracking
	durationCall := benchmarkCalls[0]
	if !strings.HasSuffix(durationCall.name, "duration_ms") {
		t.Errorf("expected duration_ms suffix, got %q", durationCall.name)
	}
	if len(durationCall.tags) != 1 || !strings.Contains(durationCall.tags[0], "integration_test_org") {
		t.Errorf("expected org tag in duration, got %v", durationCall.tags)
	}
}

// TestMetricsIntegrationFailureCase verifies that failure metrics are properly
// emitted when a tool execution fails.
func TestMetricsIntegrationFailureCase(t *testing.T) {
	withTestOrgResolver(t, orgResolverFunc(func(ctx context.Context, orgID string) (string, error) {
		return "Failure Test Org", nil
	}))

	origInc := watchmanIncrementWithTags
	origBench := watchmanBenchmarkWithTags
	defer func() {
		watchmanIncrementWithTags = origInc
		watchmanBenchmarkWithTags = origBench
	}()

	type metricCall struct {
		name string
	}
	var incrementCalls []metricCall
	var mu sync.Mutex

	watchmanIncrementWithTags = func(metric string, tags []string) error {
		mu.Lock()
		defer mu.Unlock()
		incrementCalls = append(incrementCalls, metricCall{name: metric})
		return nil
	}

	watchmanBenchmarkWithTags = func(start time.Time, name string, tags []string) error {
		return nil
	}

	// Simulate a failed tool execution
	ctx := context.Background()
	metrics := NewToolMetrics(ctx, "failure_test_tool", "org-xyz789")
	if metrics == nil {
		t.Fatal("expected non-nil metrics")
	}

	metrics.IncrementTotal()
	time.Sleep(5 * time.Millisecond) // Simulate work
	metrics.TrackDuration(time.Now().Add(-5 * time.Millisecond))
	metrics.IncrementFailure()

	// Verify failure metrics were emitted
	mu.Lock()
	defer mu.Unlock()

	if len(incrementCalls) != 2 {
		t.Fatalf("expected 2 increment calls (total, failure), got %d", len(incrementCalls))
	}

	// Verify failure counter
	failureCall := incrementCalls[1]
	if !strings.HasSuffix(failureCall.name, "count_failed") {
		t.Errorf("expected count_failed suffix, got %q", failureCall.name)
	}
}
