package shared

import (
	"errors"
	"fmt"

	"github.com/mark3labs/mcp-go/mcp"

	"github.com/semaphoreio/semaphore/mcp_server/pkg/authz"
)

const rbacUnavailableMessage = `Authorization service is not configured.

The RBAC gRPC endpoint must be set (INTERNAL_API_URL_RBAC / MCP_RBAC_GRPC_ENDPOINT) so we can verify permissions. Contact an administrator to configure the service and retry.`

// OrgAuthorizationError formats a consistent MCP error result for organization-scoped permission checks.
func OrgAuthorizationError(err error, orgID, permission string) *mcp.CallToolResult {
	switch {
	case errors.Is(err, authz.ErrRBACUnavailable):
		return mcp.NewToolResultError(rbacUnavailableMessage)
	case errors.Is(err, authz.ErrPermissionDenied):
		return mcp.NewToolResultError(fmt.Sprintf(`Permission denied while accessing organization %s.

The authenticated user is missing the %q permission for this organization. Request access from an administrator or choose another organization.`, orgID, permission))
	default:
		return mcp.NewToolResultError(fmt.Sprintf("Authorization check failed: %v", err))
	}
}

// ProjectAuthorizationError formats a consistent MCP error result for project-scoped permission checks.
func ProjectAuthorizationError(err error, orgID, projectID, permission string) *mcp.CallToolResult {
	switch {
	case errors.Is(err, authz.ErrRBACUnavailable):
		return mcp.NewToolResultError(rbacUnavailableMessage)
	case errors.Is(err, authz.ErrPermissionDenied):
		return mcp.NewToolResultError(fmt.Sprintf(`Permission denied while accessing project %s in organization %s.

The authenticated user is missing the %q permission for this project. Request access from an administrator or try a different project.`, projectID, orgID, permission))
	default:
		return mcp.NewToolResultError(fmt.Sprintf("Authorization check failed: %v", err))
	}
}
