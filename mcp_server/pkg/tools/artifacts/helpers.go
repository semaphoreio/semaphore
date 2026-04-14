package artifacts

import (
	"context"
	"errors"
	"fmt"
	"net/url"
	"path"
	"strings"

	"github.com/mark3labs/mcp-go/mcp"
	"github.com/sirupsen/logrus"

	"github.com/semaphoreio/semaphore/mcp_server/pkg/authz"
	artifacthubpb "github.com/semaphoreio/semaphore/mcp_server/pkg/internal_api/artifacthub"
	workflowpb "github.com/semaphoreio/semaphore/mcp_server/pkg/internal_api/plumber_w_f.workflow"
	projecthubpb "github.com/semaphoreio/semaphore/mcp_server/pkg/internal_api/projecthub"
	"github.com/semaphoreio/semaphore/mcp_server/pkg/internalapi"
	"github.com/semaphoreio/semaphore/mcp_server/pkg/logging"
	"github.com/semaphoreio/semaphore/mcp_server/pkg/tools/internal/clients"
	"github.com/semaphoreio/semaphore/mcp_server/pkg/tools/internal/shared"
	grpccodes "google.golang.org/grpc/codes"
	grpcstatus "google.golang.org/grpc/status"
)

const (
	scopeProjects  = "projects"
	scopeWorkflows = "workflows"
	scopeJobs      = "jobs"
)

var errArtifactPathNotFound = errors.New("artifact path not found")

type scopeResolution struct {
	OrganizationID string
	ProjectID      string
}

type accessContext struct {
	OrganizationID  string
	ProjectID       string
	ArtifactStoreID string
}

type commonRequestParams struct {
	UserID            string
	Scope             string
	ScopeID           string
	ProvidedProjectID string
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

func resolveCommonRequestParams(req mcp.CallToolRequest, action string) (commonRequestParams, error) {
	userID, err := extractUserID(req, action)
	if err != nil {
		return commonRequestParams{}, err
	}

	scope, scopeID, err := requireScopeAndID(req)
	if err != nil {
		return commonRequestParams{}, err
	}

	providedProjectID, err := optionalProjectID(req)
	if err != nil {
		return commonRequestParams{}, err
	}

	return commonRequestParams{
		UserID:            userID,
		Scope:             scope,
		ScopeID:           scopeID,
		ProvidedProjectID: providedProjectID,
	}, nil
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
	value := raw
	if value != strings.TrimSpace(value) {
		return "", fmt.Errorf("path must not contain leading or trailing whitespace")
	}
	if value == "" {
		if required {
			return "", fmt.Errorf("path must be present")
		}
		return "", nil
	}
	if containsControlRune(value) {
		return "", fmt.Errorf("path contains control characters")
	}

	if strings.HasPrefix(value, "/") {
		return "", fmt.Errorf("absolute paths are not allowed")
	}
	if strings.Contains(value, `\`) {
		return "", fmt.Errorf("invalid path")
	}
	if containsEncodedPathSeparatorOrControl(value) {
		return "", fmt.Errorf("encoded path separators are not allowed")
	}

	if err := validateEncodedPathStructure(value); err != nil {
		return "", err
	}

	segments := strings.Split(value, "/")
	cleaned := make([]string, 0, len(segments))
	for _, seg := range segments {
		if seg != strings.TrimSpace(seg) {
			return "", fmt.Errorf("path segments must not contain leading or trailing whitespace")
		}
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

	cleanedPath := strings.Join(cleaned, "/")
	normalized := strings.TrimPrefix(path.Clean("/"+cleanedPath), "/")
	if normalized == "." {
		normalized = ""
	}
	if normalized == "" {
		if required {
			return "", fmt.Errorf("path must be present")
		}
		return "", nil
	}
	if normalized != cleanedPath {
		return "", fmt.Errorf("path traversal is not allowed")
	}

	return normalized, nil
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
	name := strings.TrimPrefix(fullPath, "/")
	if name == "" {
		return ""
	}

	prefix := fmt.Sprintf("artifacts/%s/%s/", scope, scopeID)
	if !strings.HasPrefix(name, prefix) {
		return ""
	}
	return strings.TrimPrefix(name, prefix)
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
	permissions []string,
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

	var (
		project        *projecthubpb.Project
		projectStoreID string
		toolErr        *mcp.CallToolResult
	)
	if scope == scopeProjects {
		project, err = clients.DescribeProject(ctx, api, orgID, userID, projectID)
		if err != nil {
			return accessContext{}, mcp.NewToolResultError(err.Error())
		}

		projectStoreID, toolErr = validateProjectDescribe(toolName, orgID, projectID, project)
		if toolErr != nil {
			return accessContext{}, toolErr
		}
	}

	for _, permission := range permissions {
		if err := authz.CheckProjectPermission(ctx, api, userID, orgID, projectID, permission); err != nil {
			return accessContext{}, shared.ProjectAuthorizationError(err, orgID, projectID, permission)
		}
	}

	if project == nil {
		project, err = clients.DescribeProject(ctx, api, orgID, userID, projectID)
		if err != nil {
			return accessContext{}, mcp.NewToolResultError(err.Error())
		}

		projectStoreID, toolErr = validateProjectDescribe(toolName, orgID, projectID, project)
		if toolErr != nil {
			return accessContext{}, toolErr
		}
	}

	return accessContext{
		OrganizationID:  orgID,
		ProjectID:       projectID,
		ArtifactStoreID: projectStoreID,
	}, nil
}

func validateProjectDescribe(toolName, orgID, projectID string, project *projecthubpb.Project) (string, *mcp.CallToolResult) {
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
		return "", shared.ScopeMismatchError(toolName, "organization")
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
		return "", shared.ScopeMismatchError(toolName, "project")
	}

	if projectStoreID == "" {
		return "", mcp.NewToolResultError("project is missing an artifact_store_id; cannot access artifacts")
	}

	return projectStoreID, nil
}

func listPath(ctx context.Context, api internalapi.Provider, artifactID, directory string, limit int) ([]*artifacthubpb.ListItem, error) {
	if limit <= 0 || limit > maxListItems {
		limit = maxListItems
	}

	resp, err := listPathRPC(ctx, api, &artifacthubpb.ListPathRequest{
		ArtifactId: artifactID,
		Path:       directory,
		Limit:      int32(limit), // #nosec G115 -- limit is bounded to [1, maxListItems] above
	})
	if err != nil {
		return nil, formatArtifacthubPathError("ListPath", err, limit)
	}

	return resp.GetItems(), nil
}

func listPathRPC(ctx context.Context, api internalapi.Provider, req *artifacthubpb.ListPathRequest) (*artifacthubpb.ListPathResponse, error) {
	client := api.Artifacthub()
	if client == nil {
		return nil, fmt.Errorf("artifacthub gRPC endpoint is not configured")
	}

	callCtx, cancel := context.WithTimeout(ctx, api.CallTimeout())
	defer cancel()

	resp, err := client.ListPath(callCtx, req)
	if err != nil {
		logging.ForComponent("rpc").
			WithFields(logrus.Fields{
				"rpc":        "artifacthub.ListPath",
				"artifactId": req.GetArtifactId(),
				"path":       req.GetPath(),
			}).
			WithError(err).
			Error("ListPath RPC failed")
		return nil, err
	}

	return resp, nil
}

func getSignedURLs(ctx context.Context, api internalapi.Provider, artifactID, path, method string) ([]signedURLItem, error) {
	client := api.Artifacthub()
	if client == nil {
		return nil, fmt.Errorf("artifacthub gRPC endpoint is not configured")
	}

	callCtx, cancel := context.WithTimeout(ctx, api.CallTimeout())
	defer cancel()

	resp, err := client.GetSignedURLS(callCtx, &artifacthubpb.GetSignedURLSRequest{
		ArtifactId: artifactID,
		Path:       path,
		Method:     method,
		Limit:      int32(maxListItems),
	})
	if err != nil {
		if grpcstatus.Code(err) == grpccodes.Unimplemented {
			logging.ForComponent("rpc").
				WithFields(logrus.Fields{
					"rpc":        "artifacthub.GetSignedURLS",
					"artifactId": artifactID,
					"path":       path,
					"method":     method,
				}).
				WithError(err).
				Warn("GetSignedURLS RPC unavailable; falling back to GetSignedURL")

			if validateErr := validateFallbackSignedURLPath(ctx, api, artifactID, path); validateErr != nil {
				return nil, validateErr
			}

			fallbackURL, fallbackErr := getSignedURLFallback(ctx, api, artifactID, path, method)
			if fallbackErr != nil {
				logging.ForComponent("rpc").
					WithFields(logrus.Fields{
						"rpc":        "artifacthub.GetSignedURL",
						"artifactId": artifactID,
						"path":       path,
						"method":     method,
					}).
					WithError(fallbackErr).
					Error("GetSignedURL fallback RPC failed")
				return nil, formatArtifacthubPathError("GetSignedURL", fallbackErr, maxListItems)
			}

			return []signedURLItem{fallbackURL}, nil
		}

		logging.ForComponent("rpc").
			WithFields(logrus.Fields{
				"rpc":        "artifacthub.GetSignedURLS",
				"artifactId": artifactID,
				"path":       path,
				"method":     method,
			}).
			WithError(err).
			Error("GetSignedURLS RPC failed")
		return nil, formatArtifacthubPathError("GetSignedURLS", err, maxListItems)
	}

	urls := make([]signedURLItem, 0, len(resp.GetUrls()))
	for _, item := range resp.GetUrls() {
		if item == nil {
			continue
		}

		url := strings.TrimSpace(item.GetUrl())
		if url == "" {
			continue
		}

		itemMethod := strings.ToUpper(strings.TrimSpace(item.GetMethod().String()))
		if itemMethod != "GET" && itemMethod != "HEAD" {
			logging.ForComponent("rpc").
				WithFields(logrus.Fields{
					"rpc":              "artifacthub.GetSignedURLS",
					"artifactId":       artifactID,
					"path":             path,
					"requestedMethod":  method,
					"responseURL":      url,
					"responseMethod":   item.GetMethod().String(),
					"responseMethodID": int32(item.GetMethod()),
				}).
				Warn("GetSignedURLS returned an unexpected method; skipping entry")
			continue
		}

		urls = append(urls, signedURLItem{
			URL:    url,
			Method: itemMethod,
		})
	}

	if len(urls) == 0 {
		return nil, fmt.Errorf("artifact service returned malformed response: no signed URLs")
	}

	return urls, nil
}

func validateFallbackSignedURLPath(ctx context.Context, api internalapi.Provider, artifactID, targetPath string) error {
	normalizedTargetPath := strings.TrimSpace(targetPath)
	if normalizedTargetPath == "" {
		return errArtifactPathNotFound
	}
	if strings.HasSuffix(normalizedTargetPath, "/") {
		return fmt.Errorf("directory signed URLs require artifacthub GetSignedURLS RPC; upgrade the artifacthub deployment")
	}

	parentDir := path.Dir(normalizedTargetPath)
	if parentDir == "." {
		parentDir = ""
	}
	if parentDir != "" && !strings.HasSuffix(parentDir, "/") {
		parentDir += "/"
	}

	resp, err := listPathRPC(ctx, api, &artifacthubpb.ListPathRequest{
		ArtifactId: artifactID,
		Path:       parentDir,
		Limit:      int32(maxListItems),
	})
	if err != nil {
		if grpcstatus.Code(err) == grpccodes.FailedPrecondition {
			return fmt.Errorf(
				"directory signed URLs require artifacthub GetSignedURLS RPC; upgrade the artifacthub deployment",
			)
		}
		return formatArtifacthubPathError("ListPath", err, maxListItems)
	}

	normalizedDirPrefix := normalizedTargetPath + "/"
	hasDirectoryChildren := false
	for _, item := range resp.GetItems() {
		if item == nil {
			continue
		}

		name := strings.TrimSpace(item.GetName())
		if name == "" {
			continue
		}

		if name == normalizedTargetPath && !item.GetIsDirectory() {
			return nil
		}

		if name == normalizedTargetPath && item.GetIsDirectory() {
			hasDirectoryChildren = true
			continue
		}

		if strings.HasPrefix(name, normalizedDirPrefix) {
			hasDirectoryChildren = true
		}
	}

	if hasDirectoryChildren {
		return fmt.Errorf(
			"directory signed URLs require artifacthub GetSignedURLS RPC; upgrade the artifacthub deployment",
		)
	}

	return errArtifactPathNotFound
}

func getSignedURLFallback(ctx context.Context, api internalapi.Provider, artifactID, path, method string) (signedURLItem, error) {
	client := api.Artifacthub()
	if client == nil {
		return signedURLItem{}, fmt.Errorf("artifacthub gRPC endpoint is not configured")
	}

	callCtx, cancel := context.WithTimeout(ctx, api.CallTimeout())
	defer cancel()

	resp, err := client.GetSignedURL(callCtx, &artifacthubpb.GetSignedURLRequest{
		ArtifactId: artifactID,
		Path:       path,
		Method:     method,
	})
	if err != nil {
		return signedURLItem{}, err
	}

	url := strings.TrimSpace(resp.GetUrl())
	if url == "" {
		return signedURLItem{}, fmt.Errorf("artifact service returned malformed response: empty signed URL")
	}

	return signedURLItem{
		URL:    url,
		Method: method,
	}, nil
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

func containsControlRune(value string) bool {
	for _, r := range value {
		if r < 32 || r == 127 {
			return true
		}
	}
	return false
}

func containsEncodedPathSeparatorOrControl(value string) bool {
	lower := strings.ToLower(value)
	for _, token := range []string{"%00", "%2f", "%5c"} {
		if strings.Contains(lower, token) {
			return true
		}
	}
	return false
}

func formatArtifacthubPathError(operation string, err error, limit int) error {
	if st, ok := grpcstatus.FromError(err); ok {
		switch st.Code() {
		case grpccodes.NotFound:
			if strings.Contains(strings.ToLower(st.Message()), "artifact store not found") {
				return errors.New("artifact store not found")
			}
			return errArtifactPathNotFound
		case grpccodes.FailedPrecondition:
			if limit <= 0 || limit > maxListItems {
				limit = maxListItems
			}
			return fmt.Errorf(
				"artifacthub %s failed: path resolves to too many files (maximum %d per request); narrow the path and retry",
				operation,
				limit,
			)
		}
	}

	return fmt.Errorf("artifacthub %s failed: %w", operation, err)
}

func validateEncodedPathStructure(value string) error {
	if !strings.Contains(value, "%") {
		return nil
	}

	const maxDecodePasses = 3
	decoded := value
	for pass := 0; pass < maxDecodePasses; pass++ {
		prepared := normalizeLiteralPercents(decoded)
		next, err := url.PathUnescape(prepared)
		if err != nil {
			return fmt.Errorf("path contains invalid percent-encoding")
		}
		if next == decoded {
			return nil
		}
		if containsEncodedPathSeparatorOrControl(next) {
			return fmt.Errorf("encoded path separators are not allowed")
		}
		if err := validateRelativePathStructure(next); err != nil {
			return err
		}
		decoded = next
	}

	if hasEscapablePercentTriplet(decoded) {
		return fmt.Errorf("path contains excessively nested percent-encoding")
	}

	return nil
}

func normalizeLiteralPercents(value string) string {
	if !strings.Contains(value, "%") {
		return value
	}

	var out strings.Builder
	out.Grow(len(value) + 8)

	for i := 0; i < len(value); i++ {
		if value[i] == '%' && i+2 < len(value) && isHexByte(value[i+1]) && isHexByte(value[i+2]) {
			out.WriteByte('%')
			out.WriteByte(value[i+1])
			out.WriteByte(value[i+2])
			i += 2
			continue
		}
		if value[i] == '%' {
			out.WriteString("%25")
			continue
		}
		out.WriteByte(value[i])
	}

	return out.String()
}

func hasEscapablePercentTriplet(value string) bool {
	for i := 0; i+2 < len(value); i++ {
		if value[i] == '%' && isHexByte(value[i+1]) && isHexByte(value[i+2]) {
			return true
		}
	}
	return false
}

func isHexByte(b byte) bool {
	return (b >= '0' && b <= '9') ||
		(b >= 'a' && b <= 'f') ||
		(b >= 'A' && b <= 'F')
}

func validateRelativePathStructure(value string) error {
	if value != strings.TrimSpace(value) {
		return fmt.Errorf("path must not contain leading or trailing whitespace")
	}
	if containsControlRune(value) {
		return fmt.Errorf("path contains control characters")
	}
	if strings.HasPrefix(value, "/") {
		return fmt.Errorf("absolute paths are not allowed")
	}
	if strings.Contains(value, `\`) {
		return fmt.Errorf("invalid path")
	}

	segments := strings.Split(value, "/")
	for _, seg := range segments {
		if seg != strings.TrimSpace(seg) {
			return fmt.Errorf("path segments must not contain leading or trailing whitespace")
		}
		if seg == "" {
			continue
		}
		if seg == "." || seg == ".." {
			return fmt.Errorf("path traversal is not allowed")
		}
	}

	return nil
}
