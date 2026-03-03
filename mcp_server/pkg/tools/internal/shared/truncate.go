package shared

import "strings"

const (
	// MaxResponseChars is the maximum number of characters in any tool response.
	MaxResponseChars = 25000

	// TruncationWarningChars is the threshold at which we warn about truncation.
	TruncationWarningChars = 20000

	// TruncationSuffix is appended to truncated responses.
	TruncationSuffix = "\n\n---\n\n⚠️ **Response truncated** - Output exceeded character limit. Use pagination to see more results."
)

// TruncateResponse ensures a response doesn't exceed maximum character limits.
// It attempts to truncate at a line boundary for cleaner results.
func TruncateResponse(content string, maxChars int) string {
	if len(content) <= maxChars {
		return content
	}

	// Calculate available space after suffix
	available := maxChars - len(TruncationSuffix)
	if available < 1000 {
		available = 1000 // Minimum viable truncation
	}

	truncated := content[:available]

	// Try to truncate at a line boundary for cleaner output
	if idx := strings.LastIndex(truncated, "\n"); idx > available-1000 {
		truncated = truncated[:idx]
	}

	return truncated + TruncationSuffix
}

// TruncateList truncates a slice of items if it would exceed reasonable display limits.
func TruncateList(items []string, maxItems int) ([]string, bool) {
	if len(items) <= maxItems {
		return items, false
	}
	return items[:maxItems], true
}
