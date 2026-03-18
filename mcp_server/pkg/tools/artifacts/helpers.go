package artifacts

import (
	"context"
	"fmt"
	"strings"

	"github.com/mark3labs/mcp-go/mcp"
	"github.com/sirupsen/logrus"

	"github.com/semaphoreio/semaphore/mcp_server/pkg/authz"
	artifacthubpb "github.com/semaphoreio/semaphore/mcp_server/pkg/internal_api/artifacthub"
	workflowpb "github.com/semaphoreio/semaphore/mcp_server/pkg/internal_api/plumber_w_f.workflow"
	"github.com/semaphoreio/semaphore/mcp_server/pkg/internalapi"
	"github.com/semaphoreio/semaphore/mcp_server/pkg/logging"
	"github.com/semaphoreio/semaphore/mcp_server/pkg/tools/internal/clients"
	"github.com/semaphoreio/semaphore/mcp_server/pkg/tools/internal/shared"
)

const (
	scopeProjects  = "projects"
	scopeWorkflows = "workflows"
	scopeJobs      = "jobs"
)

type scopeResolution struct {
	OrganizationID string
	ProjectID      string
}

type accessContext struct {
	OrganizationID  string
	ProjectID       string
	ArtifactStoreID string
}

func requireOrganizationID(req mcp.CallToolRequest) (string, error) {
	orgIDRaw, err := req.RequireString("organization_id")
	if err != nil {
		return "", fmt.Errorf("organization_id is required. Use organizations_list to select an organization first")
	}

	orgID := strings.TrimSpace(orgIDRaw)
	if err := shared.ValidateUUID(orgID, "organization_id"); err != nil {
		return "", err
	}
	return orgID, nil
}

func requireScopeAndID(req mcp.CallToolRequest) (string, string, error) {
	scopeRaw, err := req.RequireString("scope")
	if err != nil {
		return "", "", fmt.Errorf("scope is required")
	}
	scope, err := normalizeScope(scopeRaw)
	if err != nil {
		return "", "", err
	}

	scopeIDRaw, err := req.RequireString("scope_id")
	if err != nil {
		return "", "", fmt.Errorf("scope_id is required")
	}
	scopeID := strings.TrimSpace(scopeIDRaw)
	if err := shared.ValidateUUID(scopeID, "scope_id"); err != nil {
		return "", "", err
	}

	return scope, scopeID, nil
}

func optionalProjectID(req mcp.CallToolRequest) (string, error) {
	projectID := strings.TrimSpace(req.GetString("project_id", ""))
	if projectID == "" {
		return "", nil
	}
	if err := shared.ValidateUUID(projectID, "project_id"); err != nil {
		return "", err
	}
	return projectID, nil
}

func extractUserID(req mcp.CallToolRequest, action string) (string, error) {
	userID := strings.ToLower(strings.TrimSpace(req.Header.Get("X-Semaphore-User-ID")))
	if err := shared.ValidateUUID(userID, "x-semaphore-user-id header"); err != nil {
		return "", fmt.Errorf(`%v

The authentication layer must inject the X-Semaphore-User-ID header so we can enforce project permissions before %s.

Troubleshooting:
- Ensure requests pass through the authenticated proxy
- Verify the header value is a UUID (xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx)
- Retry once the header is present`, err, action)
	}
	return userID, nil
}

func normalizeScope(raw string) (string, error) {
	scope := strings.ToLower(strings.TrimSpace(raw))
	switch scope {
	case scopeProjects, scopeWorkflows, scopeJobs:
		return scope, nil
	default:
		return "", fmt.Errorf("scope must be one of: projects, workflows, jobs")
	}
}

func normalizeMethod(raw string) (string, error) {
	method := strings.ToUpper(strings.TrimSpace(raw))
	if method == "" {
		return "GET", nil
	}
	if method != "GET" && method != "HEAD" {
		return "", fmt.Errorf("method must be one of: GET, HEAD")
	}
	return method, nil
}

func sanitizeRelativePath(raw string, required bool) (string, error) {
	value := strings.TrimSpace(raw)
	if value == "" {
		if required {
			return "", fmt.Errorf("path must be present")
		}
		return "", nil
	}

	if strings.HasPrefix(value, "/") {
		return "", fmt.Errorf("absolute paths are not allowed")
	}
	if strings.Contains(value, `\`) {
		return "", fmt.Errorf("invalid path")
	}

	segments := strings.Split(value, "/")
	cleaned := make([]string, 0, len(segments))
	for _, seg := range segments {
		seg = strings.TrimSpace(seg)
		if seg == "" {
			continue
		}
		if seg == "." || seg == ".." {
			return "", fmt.Errorf("path traversal is not allowed")
		}
		cleaned = append(cleaned, seg)
	}

	if len(cleaned) == 0 {
		if required {
			return "", fmt.Errorf("path must be present")
		}
		return "", nil
	}

	return strings.Join(cleaned, "/"), nil
}

func parseLimit(req mcp.CallToolRequest) (int, error) {
	limit := req.GetInt("limit", defaultListLimit)
	if limit <= 0 || limit > maxListLimit {
		return 0, fmt.Errorf("limit must be an integer between 1 and %d", maxListLimit)
	}
	return limit, nil
}

func artifactPath(scope, scopeID, relativePath string) string {
	base := fmt.Sprintf("artifacts/%s/%s/", scope, scopeID)
	if relativePath == "" {
		return base
	}
	return base + relativePath
}

func toRelativeArtifactPath(fullPath, scope, scopeID string) string {
	name := strings.TrimSpace(strings.TrimPrefix(fullPath, "/"))
	if name == "" {
		return ""
	}

	prefix := fmt.Sprintf("artifacts/%s/%s/", scope, scopeID)
	if strings.HasPrefix(name, prefix) {
		return strings.TrimPrefix(name, prefix)
	}

	trimmedPrefix := strings.TrimSuffix(prefix, "/")
	if name == trimmedPrefix {
		return ""
	}
	if strings.HasPrefix(name, trimmedPrefix+"/") {
		return strings.TrimPrefix(name, trimmedPrefix+"/")
	}

	return name
}

func sameID(a, b string) bool {
	return strings.EqualFold(strings.TrimSpace(a), strings.TrimSpace(b))
}

func resolveScope(ctx context.Context, api internalapi.Provider, scope, scopeID string) (scopeResolution, error) {
	switch scope {
	case scopeProjects:
		return scopeResolution{ProjectID: scopeID}, nil
	case scopeJobs:
		return resolveJobScope(ctx, api, scopeID)
	case scopeWorkflows:
		return resolveWorkflowScope(ctx, api, scopeID)
	default:
		return scopeResolution{}, fmt.Errorf("scope must be one of: projects, workflows, jobs")
	}
}

func resolveJobScope(ctx context.Context, api internalapi.Provider, scopeID string) (scopeResolution, error) {
	job, err := clients.DescribeJob(ctx, api, scopeID)
	if err != nil {
		return scopeResolution{}, err
	}

	orgID := strings.TrimSpace(job.GetOrganizationId())
	if err := shared.ValidateUUID(orgID, "job organization_id"); err != nil {
		return scopeResolution{}, err
	}

	projectID := strings.TrimSpace(job.GetProjectId())
	if err := shared.ValidateUUID(projectID, "job project_id"); err != nil {
		return scopeResolution{}, err
	}

	return scopeResolution{
		OrganizationID: orgID,
		ProjectID:      projectID,
	}, nil
}

func resolveWorkflowScope(ctx context.Context, api internalapi.Provider, scopeID string) (scopeResolution, error) {
	client := api.Workflow()
	if client == nil {
		return scopeResolution{}, fmt.Errorf("workflow gRPC endpoint is not configured")
	}

	callCtx, cancel := context.WithTimeout(ctx, api.CallTimeout())
	defer cancel()

	resp, err := client.Describe(callCtx, &workflowpb.DescribeRequest{WfId: scopeID})
	if err != nil {
		logging.ForComponent("rpc").
			WithFields(logrus.Fields{
				"rpc":  "workflow.Describe",
				"wfId": scopeID,
			}).
			WithError(err).
			Error("workflow describe RPC failed")
		return scopeResolution{}, fmt.Errorf("workflow describe RPC failed: %w", err)
	}

	if err := shared.CheckStatus(resp.GetStatus()); err != nil {
		return scopeResolution{}, fmt.Errorf("workflow describe failed: %w", err)
	}

	workflow := resp.GetWorkflow()
	if workflow == nil {
		return scopeResolution{}, fmt.Errorf("workflow describe returned no workflow payload")
	}

	orgID := strings.TrimSpace(workflow.GetOrganizationId())
	if err := shared.ValidateUUID(orgID, "workflow organization_id"); err != nil {
		return scopeResolution{}, err
	}

	projectID := strings.TrimSpace(workflow.GetProjectId())
	if err := shared.ValidateUUID(projectID, "workflow project_id"); err != nil {
		return scopeResolution{}, err
	}

	return scopeResolution{
		OrganizationID: orgID,
		ProjectID:      projectID,
	}, nil
}

func resolveArtifactAccess(
	ctx context.Context,
	api internalapi.Provider,
	toolName string,
	userID string,
	orgID string,
	scope string,
	scopeID string,
	providedProjectID string,
) (accessContext, *mcp.CallToolResult) {
	resolved, err := resolveScope(ctx, api, scope, scopeID)
	if err != nil {
		return accessContext{}, mcp.NewToolResultError(err.Error())
	}

	if resolved.OrganizationID != "" && !sameID(resolved.OrganizationID, orgID) {
		shared.ReportScopeMismatch(shared.ScopeMismatchMetadata{
			Tool:              toolName,
			ResourceType:      scopeSingular(scope),
			ResourceID:        scopeID,
			RequestOrgID:      orgID,
			ResourceOrgID:     resolved.OrganizationID,
			RequestProjectID:  providedProjectID,
			ResourceProjectID: resolved.ProjectID,
		})
		return accessContext{}, shared.ScopeMismatchError(toolName, "organization")
	}

	projectID := resolved.ProjectID
	if providedProjectID != "" {
		if !sameID(providedProjectID, projectID) {
			shared.ReportScopeMismatch(shared.ScopeMismatchMetadata{
				Tool:              toolName,
				ResourceType:      scopeSingular(scope),
				ResourceID:        scopeID,
				RequestOrgID:      orgID,
				ResourceOrgID:     resolved.OrganizationID,
				RequestProjectID:  providedProjectID,
				ResourceProjectID: projectID,
			})
			return accessContext{}, shared.ScopeMismatchError(toolName, "project")
		}
		projectID = providedProjectID
	}

	if err := authz.CheckProjectPermission(ctx, api, userID, orgID, projectID, artifactsViewPermission); err != nil {
		return accessContext{}, shared.ProjectAuthorizationError(err, orgID, projectID, artifactsViewPermission)
	}

	project, err := clients.DescribeProject(ctx, api, orgID, userID, projectID)
	if err != nil {
		return accessContext{}, mcp.NewToolResultError(err.Error())
	}

	projectOrgID := ""
	projectMetaID := ""
	projectStoreID := ""

	if meta := project.GetMetadata(); meta != nil {
		projectOrgID = strings.TrimSpace(meta.GetOrgId())
		projectMetaID = strings.TrimSpace(meta.GetId())
	}
	if spec := project.GetSpec(); spec != nil {
		projectStoreID = strings.TrimSpace(spec.GetArtifactStoreId())
	}

	if projectOrgID == "" || !sameID(projectOrgID, orgID) {
		shared.ReportScopeMismatch(shared.ScopeMismatchMetadata{
			Tool:              toolName,
			ResourceType:      "project",
			ResourceID:        projectID,
			RequestOrgID:      orgID,
			ResourceOrgID:     projectOrgID,
			RequestProjectID:  projectID,
			ResourceProjectID: projectMetaID,
		})
		return accessContext{}, shared.ScopeMismatchError(toolName, "organization")
	}

	if projectMetaID != "" && !sameID(projectMetaID, projectID) {
		shared.ReportScopeMismatch(shared.ScopeMismatchMetadata{
			Tool:              toolName,
			ResourceType:      "project",
			ResourceID:        projectMetaID,
			RequestOrgID:      orgID,
			ResourceOrgID:     projectOrgID,
			RequestProjectID:  projectID,
			ResourceProjectID: projectMetaID,
		})
		return accessContext{}, shared.ScopeMismatchError(toolName, "project")
	}

	if projectStoreID == "" {
		return accessContext{}, mcp.NewToolResultError("project is missing an artifact_store_id; cannot access artifacts")
	}

	return accessContext{
		OrganizationID:  orgID,
		ProjectID:       projectID,
		ArtifactStoreID: projectStoreID,
	}, nil
}

func listPath(ctx context.Context, api internalapi.Provider, artifactID, directory string) ([]*artifacthubpb.ListItem, error) {
	client := api.Artifacthub()
	if client == nil {
		return nil, fmt.Errorf("artifacthub gRPC endpoint is not configured")
	}

	callCtx, cancel := context.WithTimeout(ctx, api.CallTimeout())
	defer cancel()

	resp, err := client.ListPath(callCtx, &artifacthubpb.ListPathRequest{
		ArtifactId: artifactID,
		Path:       directory,
	})
	if err != nil {
		logging.ForComponent("rpc").
			WithFields(logrus.Fields{
				"rpc":        "artifacthub.ListPath",
				"artifactId": artifactID,
				"path":       directory,
			}).
			WithError(err).
			Error("ListPath RPC failed")
		return nil, fmt.Errorf("artifacthub ListPath failed: %w", err)
	}

	return resp.GetItems(), nil
}

func getSignedURL(ctx context.Context, api internalapi.Provider, artifactID, path, method string) (string, error) {
	client := api.Artifacthub()
	if client == nil {
		return "", fmt.Errorf("artifacthub gRPC endpoint is not configured")
	}

	callCtx, cancel := context.WithTimeout(ctx, api.CallTimeout())
	defer cancel()

	resp, err := client.GetSignedURL(callCtx, &artifacthubpb.GetSignedURLRequest{
		ArtifactId: artifactID,
		Path:       path,
		Method:     method,
	})
	if err != nil {
		logging.ForComponent("rpc").
			WithFields(logrus.Fields{
				"rpc":        "artifacthub.GetSignedURL",
				"artifactId": artifactID,
				"path":       path,
				"method":     method,
			}).
			WithError(err).
			Error("GetSignedURL RPC failed")
		return "", fmt.Errorf("artifacthub GetSignedURL failed: %w", err)
	}

	url := strings.TrimSpace(resp.GetUrl())
	if url == "" {
		return "", fmt.Errorf("artifacthub GetSignedURL returned an empty url")
	}

	return url, nil
}

func scopeSingular(scope string) string {
	switch scope {
	case scopeProjects:
		return "project"
	case scopeWorkflows:
		return "workflow"
	case scopeJobs:
		return "job"
	default:
		return "resource"
	}
}
