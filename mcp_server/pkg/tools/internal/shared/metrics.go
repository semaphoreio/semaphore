package shared

import (
	"strings"
	"time"

	watchman "github.com/renderedtext/go-watchman"

	"github.com/semaphoreio/semaphore/mcp_server/pkg/logging"
)

// ToolMetrics emits Watchman metrics for a specific tool invocation.
type ToolMetrics struct {
	base string
	tags []string
}

// NewToolMetrics prepares a metrics emitter scoped to a tool and optional organization ID.
func NewToolMetrics(baseMetricName, toolName, orgID string) *ToolMetrics {
	base := strings.TrimSpace(baseMetricName)
	if base == "" {
		return nil
	}

	tags := make([]string, 0, 3)
	if tag := sanitizeMetricTag("tool_" + strings.TrimSpace(toolName)); tag != "" {
		tags = append(tags, tag)
	}

	if normalizedOrg := strings.TrimSpace(strings.ToLower(orgID)); normalizedOrg != "" {
		if tag := sanitizeMetricTag("org_" + normalizedOrg); tag != "" {
			tags = append(tags, tag)
		}
	}

	if len(tags) == 0 {
		tags = append(tags, "tool_unknown")
	}

	if len(tags) > 3 {
		tags = tags[:3]
	}

	return &ToolMetrics{
		base: base,
		tags: tags,
	}
}

// IncrementTotal bumps the total execution counter.
func (tm *ToolMetrics) IncrementTotal() {
	tm.increment("executions_total")
}

// IncrementSuccess bumps the successful execution counter.
func (tm *ToolMetrics) IncrementSuccess() {
	tm.increment("executions_succeeded")
}

// IncrementFailure bumps the failed execution counter.
func (tm *ToolMetrics) IncrementFailure() {
	tm.increment("executions_failed")
}

// TrackDuration submits the elapsed duration since start.
func (tm *ToolMetrics) TrackDuration(start time.Time) {
	if tm == nil {
		return
	}

	name := tm.metricName("duration_ms")
	if err := watchman.BenchmarkWithTags(start, name, tm.tags); err != nil {
		logMetricError(name, err)
	}
}

func (tm *ToolMetrics) increment(suffix string) {
	if tm == nil {
		return
	}
	name := tm.metricName(suffix)
	if err := watchman.IncrementWithTags(name, tm.tags); err != nil {
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
