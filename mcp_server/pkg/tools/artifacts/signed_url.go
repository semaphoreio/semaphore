package artifacts

import (
	"context"
	"fmt"

	"github.com/mark3labs/mcp-go/mcp"
	"github.com/mark3labs/mcp-go/server"

	"github.com/semaphoreio/semaphore/mcp_server/pkg/internalapi"
	"github.com/semaphoreio/semaphore/mcp_server/pkg/tools/internal/shared"
)

type signedURLResult struct {
	OrganizationID string `json:"organizationId"`
	ProjectID      string `json:"projectId"`
	Scope          string `json:"scope"`
	ScopeID        string `json:"scopeId"`
	Path           string `json:"path"`
	Method         string `json:"method"`
	URL            string `json:"url"`
}

func signedURLFullDescription() string {
	return `Generate a signed URL for a specific artifact path.

Use this tool to:
- Download a single artifact file from project/workflow/job scope
- Request HEAD URLs to validate availability without full download
- Retrieve a temporary URL for follow-up fetch steps

Inputs:
- organization_id (required): Organization UUID context from organizations_list
- scope (required): One of "projects", "workflows", "jobs"
- scope_id (required): UUID for the selected scope
- path (required): Relative artifact path under that scope
- method (optional): HTTP method to sign (GET or HEAD, default GET)
- project_id (optional): Expected project UUID for additional scope validation

Output:
- url: Temporary signed URL for the requested artifact path and method

Examples:
1. Get a download URL for a job artifact:
   artifacts_signed_url(organization_id="...", scope="jobs", scope_id="...", path="agent/job_logs.txt.gz")

2. Get a HEAD URL for a workflow artifact:
   artifacts_signed_url(organization_id="...", scope="workflows", scope_id="...", path="debug/workflow_logs.txt", method="HEAD")

3. Get a project artifact URL:
   artifacts_signed_url(organization_id="...", scope="projects", scope_id="...", path="releases/build.tar.gz")

Typical workflow:
1. Call artifacts_list(...) to discover available artifact paths.
2. Call artifacts_signed_url(...) for the selected path.
3. Download once and reuse the local file for analysis.`
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

		access, authErr := resolveArtifactAccess(
			ctx,
			api,
			signedURLToolName,
			params.UserID,
			orgID,
			params.Scope,
			params.ScopeID,
			params.ProvidedProjectID,
			artifactsDownloadPermission,
		)
		if authErr != nil {
			return authErr, nil
		}

		requestPath := artifactPath(params.Scope, params.ScopeID, relativePath)
		url, err := getSignedURL(ctx, api, access.ArtifactStoreID, requestPath, method)
		if err != nil {
			return mcp.NewToolResultError(err.Error()), nil
		}

		result := signedURLResult{
			OrganizationID: orgID,
			ProjectID:      access.ProjectID,
			Scope:          params.Scope,
			ScopeID:        params.ScopeID,
			Path:           relativePath,
			Method:         method,
			URL:            url,
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
	mb.H1("Artifact Signed URL")
	mb.KeyValue("Organization ID", fmt.Sprintf("`%s`", result.OrganizationID))
	mb.KeyValue("Project ID", fmt.Sprintf("`%s`", result.ProjectID))
	mb.KeyValue("Scope", fmt.Sprintf("%s (`%s`)", result.Scope, result.ScopeID))
	mb.KeyValue("Path", fmt.Sprintf("`%s`", result.Path))
	mb.KeyValue("Method", result.Method)
	mb.KeyValue("URL", result.URL)
	mb.Line()
	mb.Paragraph("Signed URLs expire quickly. Download once and reuse the local file for analysis.")
	return mb.String()
}
