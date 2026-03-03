package jobs

import (
	"context"
	"fmt"
	"strings"

	"github.com/mark3labs/mcp-go/mcp"
	"github.com/mark3labs/mcp-go/server"

	"github.com/semaphoreio/semaphore/mcp_server/pkg/authz"
	"github.com/semaphoreio/semaphore/mcp_server/pkg/internalapi"
	"github.com/semaphoreio/semaphore/mcp_server/pkg/tools/internal/shared"
)

const (
	describeToolName      = "jobs_describe"
	projectViewPermission = "project.view"
)

func describeFullDescription() string {
	return `Describe a Semaphore job by ID.

Use this tool to answer:
- “What happened to job X?”
- “Which agent ran this job and when?”
- “Was the job a debug session or self-hosted run?”

Response modes:
- summary (default): high-level status, result, pipeline and project references, debug flags, key timestamps.
- detailed: includes agent metadata, machine specs, hook/branch IDs, and a full timeline of state transitions.

Examples:
1. Get basic job status:
   jobs_describe(job_id="...", organization_id="...")

2. Get detailed job information with agent metadata:
   jobs_describe(job_id="...", organization_id="...", mode="detailed")

3. Check job result and timestamps:
   jobs_describe(job_id="...", organization_id="...", mode="summary")

Typical workflow:
1. Call jobs_describe(job_id="...") to retrieve status and timelines.
2. If the job failed, call jobs_logs(job_id="...") to stream logs.
3. Use pipelines_list(workflow_id="...") to inspect the broader pipeline context.
`
}

func newDescribeTool(name, description string) mcp.Tool {
	return mcp.NewTool(
		name,
		mcp.WithDescription(description),
		mcp.WithString(
			"organization_id",
			mcp.Required(),
			mcp.Description("Organization UUID context for this job (format: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx). Use the ID returned by semaphore_organizations_list."),
			mcp.Pattern(`^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$`),
		),
		mcp.WithString(
			"job_id",
			mcp.Required(),
			mcp.Description("Job UUID to describe (format: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx)."),
			mcp.Pattern(`^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$`),
		),
		mcp.WithString(
			"mode",
			mcp.Description("Response detail level. Use 'summary' for a concise view or 'detailed' for agent metadata and full timeline."),
			mcp.Enum("summary", "detailed"),
			mcp.DefaultString("summary"),
		),
		mcp.WithReadOnlyHintAnnotation(true),
		mcp.WithIdempotentHintAnnotation(true),
		mcp.WithOpenWorldHintAnnotation(true),
	)
}

func describeHandler(api internalapi.Provider) server.ToolHandlerFunc {
	return func(ctx context.Context, req mcp.CallToolRequest) (*mcp.CallToolResult, error) {
		orgIDRaw, err := req.RequireString("organization_id")
		if err != nil {
			return mcp.NewToolResultError("organization_id is required. Use organizations_list to capture the correct organization ID before describing jobs."), nil
		}
		orgID := strings.TrimSpace(orgIDRaw)
		if err := shared.ValidateUUID(orgID, "organization_id"); err != nil {
			return mcp.NewToolResultError(err.Error()), nil
		}

		tracker := shared.TrackToolExecution(ctx, describeToolName, orgID)
		defer tracker.Cleanup()

		if err := shared.EnsureReadToolsFeature(ctx, api, orgID); err != nil {
			return mcp.NewToolResultError(err.Error()), nil
		}

		jobIDRaw, err := req.RequireString("job_id")
		if err != nil {
			return mcp.NewToolResultError("job_id is required. Provide the job UUID (e.g., 11111111-2222-3333-4444-555555555555)."), nil
		}

		jobID := strings.TrimSpace(jobIDRaw)
		if err := shared.ValidateUUID(jobID, "job_id"); err != nil {
			return mcp.NewToolResultError(err.Error()), nil
		}

		userID := strings.ToLower(strings.TrimSpace(req.Header.Get("X-Semaphore-User-ID")))
		if err := shared.ValidateUUID(userID, "x-semaphore-user-id header"); err != nil {
			return mcp.NewToolResultError(fmt.Sprintf(`%v

The authentication layer must inject the X-Semaphore-User-ID header so we can enforce project permissions before describing jobs.

Troubleshooting:
- Ensure calls pass through the authenticated proxy
- Verify the header value is a UUID (xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx)
- Retry once the header is present`, err)), nil
		}

		mode, err := shared.NormalizeMode(req.GetString("mode", "summary"))
		if err != nil {
			return mcp.NewToolResultError(fmt.Sprintf("Invalid mode parameter: %v", err)), nil
		}

		job, err := fetchJob(ctx, api, jobID)
		if err != nil {
			return mcp.NewToolResultError(err.Error()), nil
		}

		jobProjectID := strings.TrimSpace(job.GetProjectId())
		jobOrg := strings.TrimSpace(job.GetOrganizationId())
		if jobOrg == "" || !strings.EqualFold(jobOrg, orgID) {
			shared.ReportScopeMismatch(shared.ScopeMismatchMetadata{
				Tool:              describeToolName,
				ResourceType:      "job",
				ResourceID:        jobID,
				RequestOrgID:      orgID,
				ResourceOrgID:     job.GetOrganizationId(),
				RequestProjectID:  "",
				ResourceProjectID: jobProjectID,
			})
			return shared.ScopeMismatchError(describeToolName, "organization"), nil
		}

		if jobProjectID == "" {
			shared.ReportScopeMismatch(shared.ScopeMismatchMetadata{
				Tool:              describeToolName,
				ResourceType:      "job",
				ResourceID:        jobID,
				RequestOrgID:      orgID,
				ResourceOrgID:     jobOrg,
				RequestProjectID:  "",
				ResourceProjectID: jobProjectID,
			})
			return shared.ScopeMismatchError(describeToolName, "project"), nil
		}

		if err := authz.CheckProjectPermission(ctx, api, userID, orgID, jobProjectID, projectViewPermission); err != nil {
			return shared.ProjectAuthorizationError(err, orgID, jobProjectID, projectViewPermission), nil
		}

		summary := summarizeJob(job)
		if summary.OrganizationID == "" || !strings.EqualFold(summary.OrganizationID, orgID) {
			shared.ReportScopeMismatch(shared.ScopeMismatchMetadata{
				Tool:              describeToolName,
				ResourceType:      "job",
				ResourceID:        summary.ID,
				RequestOrgID:      orgID,
				ResourceOrgID:     summary.OrganizationID,
				RequestProjectID:  "",
				ResourceProjectID: summary.ProjectID,
			})
			return shared.ScopeMismatchError(describeToolName, "organization"), nil
		}
		markdown := formatJobMarkdown(summary, mode)
		markdown = shared.TruncateResponse(markdown, shared.MaxResponseChars)

		tracker.MarkSuccess()
		return &mcp.CallToolResult{
			Content: []mcp.Content{
				mcp.NewTextContent(markdown),
			},
			StructuredContent: summary,
		}, nil
	}
}
