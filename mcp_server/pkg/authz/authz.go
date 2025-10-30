package authz

import (
	"context"
	"errors"
	"fmt"
	"strings"

	watchman "github.com/renderedtext/go-watchman"
	rbacpb "github.com/semaphoreio/semaphore/mcp_server/pkg/internal_api/rbac"
	"github.com/semaphoreio/semaphore/mcp_server/pkg/internalapi"
	"github.com/semaphoreio/semaphore/mcp_server/pkg/logging"
	"github.com/sirupsen/logrus"
)

var (
	// ErrPermissionDenied represents a missing RBAC permission for the caller.
	ErrPermissionDenied = errors.New("permission denied")

	// ErrRBACUnavailable indicates that the RBAC client is not configured.
	ErrRBACUnavailable = errors.New("rbac client is not configured")
)

// CheckOrgPermission ensures the caller has all requested organization-level permissions.
func CheckOrgPermission(ctx context.Context, api internalapi.Provider, userID, orgID string, permissions ...string) error {
	return checkPermissions(ctx, api, userID, orgID, "", permissions)
}

// CheckProjectPermission ensures the caller has the requested project-level permissions.
func CheckProjectPermission(ctx context.Context, api internalapi.Provider, userID, orgID, projectID string, permissions ...string) error {
	return checkPermissions(ctx, api, userID, orgID, projectID, permissions)
}

func checkPermissions(ctx context.Context, api internalapi.Provider, userID, orgID, projectID string, permissions []string) error {
	if len(permissions) == 0 {
		return nil
	}

	client := api.RBAC()
	if client == nil {
		emitPermissionMetric("rbac_unavailable", orgID, projectID, permissions)
		return ErrRBACUnavailable
	}

	callCtx, cancel := context.WithTimeout(ctx, api.CallTimeout())
	defer cancel()

	req := &rbacpb.ListUserPermissionsRequest{
		UserId:    userID,
		OrgId:     orgID,
		ProjectId: projectID,
	}

	resp, err := client.ListUserPermissions(callCtx, req)
	if err != nil {
		logging.ForComponent("rbac").
			WithFields(logrus.Fields{
				"userId":    userID,
				"orgId":     orgID,
				"projectId": projectID,
				"perms":     permissions,
			}).
			WithError(err).
			Error("ListUserPermissions RPC failed")
		emitPermissionMetric("rpc_error", orgID, projectID, permissions)
		return fmt.Errorf("rbac permission lookup failed: %w", err)
	}

	granted := make(map[string]struct{}, len(resp.GetPermissions()))
	for _, perm := range resp.GetPermissions() {
		granted[strings.TrimSpace(perm)] = struct{}{}
	}

	var missing []string
	for _, perm := range permissions {
		if _, ok := granted[perm]; !ok {
			missing = append(missing, perm)
		}
	}

	if len(missing) > 0 {
		logging.ForComponent("authz").
			WithFields(logrus.Fields{
				"userId":    userID,
				"orgId":     orgID,
				"projectId": projectID,
				"missing":   missing,
			}).
			Info("permission check failed")
		emitPermissionMetric("denied", orgID, projectID, permissions)
		return fmt.Errorf("%w: missing %s", ErrPermissionDenied, strings.Join(missing, ", "))
	}

	emitPermissionMetric("granted", orgID, projectID, permissions)
	return nil
}

func emitPermissionMetric(outcome, orgID, projectID string, permissions []string) {
	scope := "organization"
	if strings.TrimSpace(projectID) != "" {
		scope = "project"
	}
	permTag := "unknown"
	if len(permissions) > 0 {
		permTag = strings.TrimSpace(permissions[0])
		if permTag == "" {
			permTag = "unknown"
		}
	}
	tags := []string{outcome, scope, permTag}
	if err := watchman.IncrementWithTags("mcp.authz.permission_check", tags); err != nil {
		logging.ForComponent("metrics").
			WithError(err).
			WithFields(logrus.Fields{
				"metric": "mcp.authz.permission_check",
				"tags":   tags,
			}).
			Debug("failed to emit Watchman metric")
	}
}
