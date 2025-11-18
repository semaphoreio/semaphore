package shared

import (
	"context"
	"strings"
	"time"

	watchman "github.com/renderedtext/go-watchman"

	"github.com/semaphoreio/semaphore/mcp_server/pkg/logging"
)

var (
	watchmanBenchmarkWithTags = watchman.BenchmarkWithTags
	watchmanIncrementWithTags = watchman.IncrementWithTags
)

// ToolMetrics emits Watchman metrics for a specific tool invocation.
type ToolMetrics struct {
	base string
	tags []string
}

// NewToolMetrics prepares a metrics emitter scoped to a tool and optional organization ID.
func NewToolMetrics(ctx context.Context, toolName, orgID string) *ToolMetrics {
	resolver := getOrgNameResolver()
	return newToolMetricsWithResolver(ctx, toolName, orgID, resolver)
}

func newToolMetricsWithResolver(ctx context.Context, toolName, orgID string, resolver OrgNameResolver) *ToolMetrics {
	name := strings.TrimSpace(toolName)
	if name == "" {
		return nil
	}

	base := "tools." + name
	tags := make([]string, 0, 1)

	if tag := resolveOrgTag(ctx, orgID, resolver); tag != "" {
		tags = append(tags, tag)
	}

	return &ToolMetrics{
		base: base,
		tags: tags,
	}
}

// IncrementTotal bumps the total execution counter.
func (tm *ToolMetrics) IncrementTotal() {
	tm.increment("count_total")
}

// IncrementSuccess bumps the successful execution counter.
func (tm *ToolMetrics) IncrementSuccess() {
	tm.increment("count_passed")
}

// IncrementFailure bumps the failed execution counter.
func (tm *ToolMetrics) IncrementFailure() {
	tm.increment("count_failed")
}

// TrackDuration submits the elapsed duration since start.
func (tm *ToolMetrics) TrackDuration(start time.Time) {
	if tm == nil {
		return
	}

	name := tm.metricName("duration_ms")
	if err := watchmanBenchmarkWithTags(start, name, tm.tags); err != nil {
		logMetricError(name, err)
	}
}

func (tm *ToolMetrics) increment(suffix string) {
	if tm == nil {
		return
	}
	name := tm.metricName(suffix)
	if err := watchmanIncrementWithTags(name, tm.tags); err != nil {
		logMetricError(name, err)
	}
}

func (tm *ToolMetrics) metricName(suffix string) string {
	if tm == nil {
		return suffix
	}
	if suffix == "" {
		return tm.base
	}
	return tm.base + "." + suffix
}

func resolveOrgTag(ctx context.Context, orgID string, resolver OrgNameResolver) string {
	orgID = strings.TrimSpace(orgID)
	if orgID == "" {
		return ""
	}

	value := orgID
	if resolver != nil {
		if name, err := resolver.Resolve(ctx, orgID); err == nil {
			name = strings.TrimSpace(name)
			if name != "" {
				value = name
			}
		} else {
			logging.ForComponent("metrics").
				WithError(err).
				WithField("orgId", orgID).
				Debug("failed to resolve organization name for metrics")
		}
	}

	return sanitizeMetricTag("org_" + value)
}

func sanitizeMetricTag(value string) string {
	value = strings.TrimSpace(strings.ToLower(value))
	if value == "" {
		return ""
	}
	value = strings.ReplaceAll(value, " ", "_")
	return value
}

func logMetricError(metric string, err error) {
	if err == nil {
		return
	}
	logging.ForComponent("metrics").
		WithError(err).
		WithField("metric", metric).
		Debug("failed to submit Watchman metric")
}

// ToolExecutionTracker helps track tool execution metrics with a consistent pattern.
// It provides methods to mark success and automatically handles cleanup via defer.
type ToolExecutionTracker struct {
	metrics *ToolMetrics
	start   time.Time
	success *bool
}

// TrackToolExecution creates a new tracker for monitoring tool execution metrics.
// It automatically increments the total counter and sets up cleanup logic.
//
// Usage:
//
//	tracker := shared.TrackToolExecution(ctx, toolName, orgID)
//	defer tracker.Cleanup()
//	// ... tool logic ...
//	tracker.MarkSuccess() // Call before successful return
func TrackToolExecution(ctx context.Context, toolName, orgID string) *ToolExecutionTracker {
	metrics := NewToolMetrics(ctx, toolName, orgID)
	if metrics != nil {
		metrics.IncrementTotal()
	}

	success := false
	return &ToolExecutionTracker{
		metrics: metrics,
		start:   time.Now(),
		success: &success,
	}
}

// MarkSuccess marks the tool execution as successful.
// This should be called just before returning a successful result.
func (t *ToolExecutionTracker) MarkSuccess() {
	if t != nil && t.success != nil {
		*t.success = true
	}
}

// Cleanup emits duration and success/failure metrics.
// This should be called via defer immediately after creating the tracker.
func (t *ToolExecutionTracker) Cleanup() {
	if t == nil || t.metrics == nil {
		return
	}
	t.metrics.TrackDuration(t.start)
	if t.success != nil && *t.success {
		t.metrics.IncrementSuccess()
	} else {
		t.metrics.IncrementFailure()
	}
}
