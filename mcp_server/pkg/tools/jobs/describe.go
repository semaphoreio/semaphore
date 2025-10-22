package jobs

import (
	"context"
	"fmt"
	"strings"

	"github.com/mark3labs/mcp-go/mcp"
	"github.com/mark3labs/mcp-go/server"

	"github.com/semaphoreio/semaphore/mcp_server/pkg/internalapi"
	"github.com/semaphoreio/semaphore/mcp_server/pkg/tools/internal/shared"
)

const (
	describeToolName       = "semaphore_jobs_describe"
	legacyDescribeToolName = "jobs_describe" // deprecated: use semaphore_jobs_describe
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
   semaphore_jobs_describe(job_id="...", organization_id="...")

2. Get detailed job information with agent metadata:
   semaphore_jobs_describe(job_id="...", organization_id="...", mode="detailed")

3. Check job result and timestamps:
   semaphore_jobs_describe(job_id="...", organization_id="...", mode="summary")

Typical workflow:
1. Call semaphore_jobs_describe(job_id="...") to retrieve status and timelines.
2. If the job failed, call semaphore_jobs_logs(job_id="...") to stream logs.
3. Use semaphore_pipelines_list(workflow_id="...") to inspect the broader pipeline context.
`
}

func describeDeprecatedDescription() string {
	return `⚠️ DEPRECATED: Use semaphore_jobs_describe instead.

This tool has been renamed to follow MCP naming conventions. The new name includes the 'semaphore_' prefix to prevent naming conflicts when using multiple MCP servers.

Please update your integrations to use: semaphore_jobs_describe

This legacy alias will be removed in a future version. See semaphore_jobs_describe for full documentation.`
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
			return mcp.NewToolResultError("organization_id is required. Use core_organizations_list to capture the correct organization ID before describing jobs."), nil
		}
		orgID := strings.TrimSpace(orgIDRaw)
		if err := shared.ValidateUUID(orgID, "organization_id"); err != nil {
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

		mode, err := shared.NormalizeMode(req.GetString("mode", "summary"))
		if err != nil {
			return mcp.NewToolResultError(fmt.Sprintf("Invalid mode parameter: %v", err)), nil
		}

		job, err := fetchJob(ctx, api, jobID)
		if err != nil {
			return mcp.NewToolResultError(err.Error()), nil
		}

		summary := summarizeJob(job)
		if summary.OrganizationID != "" && !strings.EqualFold(summary.OrganizationID, orgID) {
			return mcp.NewToolResultError(fmt.Sprintf(`Organization mismatch: job belongs to %s but you provided %s.

Use the organization_id returned by core_organizations_list for this workspace.`, summary.OrganizationID, orgID)), nil
		}
		markdown := formatJobMarkdown(summary, mode)
		markdown = shared.TruncateResponse(markdown, shared.MaxResponseChars)

		return &mcp.CallToolResult{
			Content: []mcp.Content{
				mcp.NewTextContent(markdown),
			},
			StructuredContent: summary,
		}, nil
	}
}
