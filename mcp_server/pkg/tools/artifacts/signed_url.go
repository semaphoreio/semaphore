package artifacts

import (
	"context"
	"fmt"

	"github.com/mark3labs/mcp-go/mcp"
	"github.com/mark3labs/mcp-go/server"

	"github.com/semaphoreio/semaphore/mcp_server/pkg/audit"
	"github.com/semaphoreio/semaphore/mcp_server/pkg/internalapi"
	"github.com/semaphoreio/semaphore/mcp_server/pkg/tools/internal/shared"
)

const signedURLMarkdownPreviewLimit = 100

type signedURLResult struct {
	OrganizationID string          `json:"organizationId"`
	ProjectID      string          `json:"projectId"`
	Scope          string          `json:"scope"`
	ScopeID        string          `json:"scopeId"`
	Path           string          `json:"path"`
	Method         string          `json:"method"`
	URLs           []signedURLItem `json:"urls"`
}

type signedURLItem struct {
	URL    string `json:"url"`
	Method string `json:"method"`
}

func signedURLFullDescription() string {
	return `Generate a signed URL for a single artifact file path.

Use this tool to:
- Download a single artifact file from project/workflow/job scope
- Request HEAD URLs to validate availability without full download

Inputs:
- organization_id (required): Organization UUID context from organizations_list
- scope (required): One of "projects", "workflows", "jobs"
- scope_id (required): UUID for the selected scope
- path (required): Relative artifact path under that scope (file path)
- method (optional): HTTP method to sign (GET or HEAD, default GET)
- project_id (optional): Expected project UUID for additional scope validation

Output:
- urls: A temporary signed URL for the requested path and method

Examples:
1. Get a download URL for a job artifact file:
   artifacts_signed_url(organization_id="...", scope="jobs", scope_id="...", path="agent/job_logs.txt.gz")

2. Get a project artifact URL:
   artifacts_signed_url(organization_id="...", scope="projects", scope_id="...", path="releases/build.tar.gz")

Typical workflow:
1. Call artifacts_list(...) to discover available artifact paths.
2. Call artifacts_signed_url(...) for a file path.
3. Download once and reuse the local file for analysis.

Note:
- For job-scope paths matching job_logs.txt variants, the server auto-resolves to the best available full log file (prefers txt over gz).`
}

func newSignedURLTool(name, description string) mcp.Tool {
	return mcp.NewTool(
		name,
		mcp.WithDescription(description),
		mcp.WithString(
			"organization_id",
			mcp.Required(),
			mcp.Description("Organization UUID context (format: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx)."),
			mcp.Pattern(`^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$`),
		),
		mcp.WithString(
			"scope",
			mcp.Required(),
			mcp.Description("Artifact scope. Use projects, workflows, or jobs."),
			mcp.Enum(scopeProjects, scopeWorkflows, scopeJobs),
		),
		mcp.WithString(
			"scope_id",
			mcp.Required(),
			mcp.Description("Scope UUID (project/workflow/job ID)."),
			mcp.Pattern(`^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$`),
		),
		mcp.WithString(
			"project_id",
			mcp.Description("Optional project UUID. If provided, it must match the project resolved from scope/scope_id."),
			mcp.Pattern(`^$|^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$`),
		),
		mcp.WithString(
			"path",
			mcp.Required(),
			mcp.Description("Relative artifact path within the scope root. Do not include a leading slash."),
		),
		mcp.WithString(
			"method",
			mcp.Description("HTTP method to sign. Allowed values: GET, HEAD."),
			mcp.Enum("GET", "HEAD"),
			mcp.DefaultString("GET"),
		),
		mcp.WithReadOnlyHintAnnotation(true),
		mcp.WithIdempotentHintAnnotation(true),
		mcp.WithOpenWorldHintAnnotation(true),
	)
}

func signedURLHandler(api internalapi.Provider) server.ToolHandlerFunc {
	return func(ctx context.Context, req mcp.CallToolRequest) (*mcp.CallToolResult, error) {
		orgID, err := requireOrganizationID(req)
		if err != nil {
			return mcp.NewToolResultError(err.Error()), nil
		}

		tracker := shared.TrackToolExecution(ctx, signedURLToolName, orgID)
		defer tracker.Cleanup()

		params, err := resolveCommonRequestParams(req, "generating artifact signed URLs")
		if err != nil {
			return mcp.NewToolResultError(err.Error()), nil
		}

		relativePath, err := sanitizeRelativePath(req.GetString("path", ""), true)
		if err != nil {
			return mcp.NewToolResultError(err.Error()), nil
		}

		method, err := normalizeMethod(req.GetString("method", "GET"))
		if err != nil {
			return mcp.NewToolResultError(err.Error()), nil
		}

		if err := shared.EnsureReadToolsFeature(ctx, api, orgID); err != nil {
			return mcp.NewToolResultError(err.Error()), nil
		}
		if err := shared.EnsureArtifactsToolsFeature(ctx, api, orgID); err != nil {
			return mcp.NewToolResultError(err.Error()), nil
		}

		access, authErr := resolveArtifactAccess(
			ctx,
			api,
			signedURLToolName,
			params.UserID,
			orgID,
			params.Scope,
			params.ScopeID,
			params.ProvidedProjectID,
			artifactsRequiredPermissions,
		)
		if authErr != nil {
			return authErr, nil
		}

		requestPath, resolvedPath, err := resolveSignedURLPath(
			ctx,
			api,
			orgID,
			access.ArtifactStoreID,
			params.Scope,
			params.ScopeID,
			relativePath,
		)
		if err != nil {
			return mcp.NewToolResultError(err.Error()), nil
		}

		auditEnabled, err := shared.AuditLogsFeatureEnabled(ctx, api, orgID)
		if err != nil {
			return mcp.NewToolResultError("Unable to verify audit logging availability. Please try again."), nil
		}

		if err := audit.LogArtifactDownload(ctx, req.Header, audit.ArtifactDownloadParams{
			UserID:       params.UserID,
			OrgID:        orgID,
			ResourceName: artifactPath(params.Scope, params.ScopeID, resolvedPath),
			SourceKind:   params.Scope,
			SourceID:     params.ScopeID,
			ProjectID:    access.ProjectID,
			Method:       method,
			AuditEnabled: auditEnabled,
		}); err != nil {
			return mcp.NewToolResultError("Audit logging failed for this artifact operation. Please try again."), nil
		}

		url, err := getSignedURL(ctx, api, orgID, access.ArtifactStoreID, requestPath, method)
		if err != nil {
			return mcp.NewToolResultError(err.Error()), nil
		}

		result := signedURLResult{
			OrganizationID: orgID,
			ProjectID:      access.ProjectID,
			Scope:          params.Scope,
			ScopeID:        params.ScopeID,
			Path:           resolvedPath,
			Method:         method,
			URLs:           []signedURLItem{url},
		}

		markdown := formatSignedURLMarkdown(result)
		markdown = shared.TruncateResponse(markdown, shared.MaxResponseChars)

		tracker.MarkSuccess()
		return &mcp.CallToolResult{
			Content:           []mcp.Content{mcp.NewTextContent(markdown)},
			StructuredContent: result,
		}, nil
	}
}

func formatSignedURLMarkdown(result signedURLResult) string {
	mb := shared.NewMarkdownBuilder()
	mb.H1("Artifact Signed URLs")
	mb.KeyValue("Organization ID", fmt.Sprintf("`%s`", result.OrganizationID))
	mb.KeyValue("Project ID", fmt.Sprintf("`%s`", result.ProjectID))
	mb.KeyValue("Scope", fmt.Sprintf("%s (`%s`)", result.Scope, result.ScopeID))
	mb.KeyValue("Path", fmt.Sprintf("`%s`", result.Path))
	mb.KeyValue("Requested Method", result.Method)
	mb.KeyValue("URL Count", fmt.Sprintf("%d", len(result.URLs)))
	if len(result.URLs) == 1 {
		mb.KeyValue("URL", result.URLs[0].URL)
	}
	if len(result.URLs) > 1 {
		mb.Line()
		mb.H2("URLs")
		previewCount := len(result.URLs)
		if previewCount > signedURLMarkdownPreviewLimit {
			previewCount = signedURLMarkdownPreviewLimit
		}
		for _, item := range result.URLs[:previewCount] {
			mb.ListItem(fmt.Sprintf("[%s] %s", item.Method, item.URL))
		}
		if len(result.URLs) > previewCount {
			mb.ListItem(fmt.Sprintf("... %d additional URLs omitted from markdown preview", len(result.URLs)-previewCount))
		}
	}
	mb.Line()
	mb.Paragraph("Signed URLs expire quickly. Download once and reuse the local file for analysis.")
	return mb.String()
}
