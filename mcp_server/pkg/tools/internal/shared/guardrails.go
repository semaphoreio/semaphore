package shared

import (
	"fmt"
	"strings"

	"github.com/mark3labs/mcp-go/mcp"
	watchman "github.com/renderedtext/go-watchman"
	"github.com/sirupsen/logrus"

	"github.com/semaphoreio/semaphore/mcp_server/pkg/logging"
)

// ScopeMismatchMetadata captures details about a response that violated the caller's scope.
type ScopeMismatchMetadata struct {
	Tool              string
	ResourceType      string
	ResourceID        string
	RequestOrgID      string
	ResourceOrgID     string
	RequestProjectID  string
	ResourceProjectID string
}

// ReportScopeMismatch emits structured logging and metrics for scope violations.
func ReportScopeMismatch(meta ScopeMismatchMetadata) {
	tool := strings.TrimSpace(meta.Tool)
	entry := logging.ForComponent("authz").WithFields(logrus.Fields{
		"event":               "mcp.authz.scope_mismatch",
		"tool":                tool,
		"resource_type":       strings.TrimSpace(meta.ResourceType),
		"resource_id":         strings.TrimSpace(meta.ResourceID),
		"request_org_id":      normalizeScopeValue(meta.RequestOrgID),
		"resource_org_id":     normalizeScopeValue(meta.ResourceOrgID),
		"request_project_id":  normalizeScopeValue(meta.RequestProjectID),
		"resource_project_id": normalizeScopeValue(meta.ResourceProjectID),
	})

	entry.Warn("response scope mismatch detected")

	metricTags := []string{}
	if tool != "" {
		metricTags = append(metricTags, tool)
	}
	if resourceType := strings.TrimSpace(meta.ResourceType); resourceType != "" {
		metricTags = append(metricTags, resourceType)
	}
	if len(metricTags) == 0 {
		metricTags = append(metricTags, "unknown")
	}

	if err := watchman.IncrementWithTags("mcp.authz.scope_mismatch", metricTags); err != nil {
		logging.ForComponent("metrics").
			WithError(err).
			WithField("event", "mcp.authz.scope_mismatch").
			Debug("failed to increment Watchman metric")
	}
}

// ScopeMismatchError formats a user-friendly MCP error without leaking sensitive identifiers.
func ScopeMismatchError(tool, scope string) *mcp.CallToolResult {
	safeTool := strings.TrimSpace(tool)
	if safeTool == "" {
		safeTool = "requested tool"
	}
	safeScope := strings.TrimSpace(scope)
	if safeScope == "" {
		safeScope = "requested"
	}

	message := fmt.Sprintf(`Permission denied: %s received data outside the authorized %s scope. The request was aborted. Retry once cache inconsistencies resolve or contact an administrator.`, safeTool, safeScope)
	return mcp.NewToolResultError(message)
}

func normalizeScopeValue(value string) string {
	value = strings.TrimSpace(strings.ToLower(value))
	if value == "" {
		return "(unset)"
	}
	return value
}
