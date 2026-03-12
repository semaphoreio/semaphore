package tasks

import (
	"context"
	"fmt"
	"strings"

	"github.com/mark3labs/mcp-go/mcp"
	"github.com/mark3labs/mcp-go/server"
	"github.com/sirupsen/logrus"

	"github.com/semaphoreio/semaphore/mcp_server/pkg/authz"
	schedulerpb "github.com/semaphoreio/semaphore/mcp_server/pkg/internal_api/periodic_scheduler"
	"github.com/semaphoreio/semaphore/mcp_server/pkg/internalapi"
	"github.com/semaphoreio/semaphore/mcp_server/pkg/logging"
	"github.com/semaphoreio/semaphore/mcp_server/pkg/tools/internal/shared"
	"github.com/semaphoreio/semaphore/mcp_server/pkg/utils"
)

func listFullDescription() string {
	return `List scheduled tasks (periodics) for a project.

Use this when you need to answer:
- "Show me all scheduled tasks for project X"
- "What recurring jobs are configured?"
- "List tasks that run on a schedule"

- organization_id: identify which organization's project you are querying (required)
- project_id: identify which project to list tasks from (required)
- cursor: paginate through results using the previous response's next_cursor
- limit: number of tasks to return (default 20, max 100)

Response modes:
- summary (default): task ID, name, branch, schedule, paused/suspended status
- detailed: adds description, pipeline file, parameters, timestamps

Examples:
1. List all tasks for a project:
   tasks_list(project_id="...", organization_id="...")

2. Paginate through more tasks:
   tasks_list(project_id="...", organization_id="...", cursor="opaque-token")

Next steps:
- Call tasks_describe(task_id="...") to get more details about a specific task
- Call tasks_run(task_id="...") to trigger a task immediately`
}

func newListTool(name, description string) mcp.Tool {
	return mcp.NewTool(
		name,
		mcp.WithDescription(description),
		mcp.WithString("project_id",
			mcp.Required(),
			mcp.Description("Project UUID that scopes the task search. Format: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx."),
			mcp.Pattern(`^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$`),
		),
		mcp.WithString("organization_id",
			mcp.Required(),
			mcp.Description("Organization UUID associated with the project. Keep this consistent across subsequent tool calls."),
			mcp.Pattern(`^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$`),
		),
		mcp.WithString("cursor",
			mcp.Description("Pagination token from a prior call's next_cursor. Use to fetch more tasks."),
		),
		mcp.WithNumber("limit",
			mcp.Description("Number of tasks to return (1-100). Defaults to 20."),
			mcp.Min(1),
			mcp.Max(maxLimit),
			mcp.DefaultNumber(defaultLimit),
		),
		mcp.WithString("mode",
			mcp.Description("Response detail. Use 'summary' for compact output; 'detailed' adds description, parameters, and timestamps."),
			mcp.Enum("summary", "detailed"),
			mcp.DefaultString("summary"),
		),
		mcp.WithReadOnlyHintAnnotation(true),
		mcp.WithIdempotentHintAnnotation(true),
		mcp.WithOpenWorldHintAnnotation(true),
	)
}

type taskSummary struct {
	ID           string `json:"id"`
	Name         string `json:"name"`
	Description  string `json:"description,omitempty"`
	Branch       string `json:"branch"`
	PipelineFile string `json:"pipeline_file"`
	Schedule     string `json:"schedule,omitempty"`
	Paused       bool   `json:"paused"`
	Suspended    bool   `json:"suspended"`
	UpdatedAt    string `json:"updated_at,omitempty"`
}

type listResult struct {
	Tasks      []taskSummary `json:"tasks"`
	NextCursor string        `json:"next_cursor,omitempty"`
}

func listHandler(api internalapi.Provider) server.ToolHandlerFunc {
	return func(ctx context.Context, req mcp.CallToolRequest) (*mcp.CallToolResult, error) {
		client := api.Scheduler()
		if client == nil {
			return mcp.NewToolResultError(missingSchedulerError), nil
		}

		projectIDRaw, err := req.RequireString("project_id")
		if err != nil {
			return mcp.NewToolResultError(`Missing required argument: project_id. Provide the project UUID (xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx).`), nil
		}
		projectID := strings.TrimSpace(projectIDRaw)
		if err := shared.ValidateUUID(projectID, "project_id"); err != nil {
			return mcp.NewToolResultError(err.Error()), nil
		}

		orgIDRaw, err := req.RequireString("organization_id")
		if err != nil {
			return mcp.NewToolResultError(`Missing required argument: organization_id. Provide the organization UUID returned by organizations_list.`), nil
		}
		orgID := strings.TrimSpace(orgIDRaw)
		if err := shared.ValidateUUID(orgID, "organization_id"); err != nil {
			return mcp.NewToolResultError(err.Error()), nil
		}

		tracker := shared.TrackToolExecution(ctx, listToolName, orgID)
		defer tracker.Cleanup()

		if err := shared.EnsureReadToolsFeature(ctx, api, orgID); err != nil {
			return mcp.NewToolResultError(err.Error()), nil
		}

		mode, err := shared.NormalizeMode(req.GetString("mode", "summary"))
		if err != nil {
			return mcp.NewToolResultError(fmt.Sprintf("Invalid mode parameter: %v", err)), nil
		}

		cursor, err := shared.SanitizeCursorToken(req.GetString("cursor", ""), "cursor")
		if err != nil {
			return mcp.NewToolResultError(err.Error()), nil
		}

		userID := strings.ToLower(strings.TrimSpace(req.Header.Get("X-Semaphore-User-ID")))
		if err := shared.ValidateUUID(userID, "x-semaphore-user-id header"); err != nil {
			return mcp.NewToolResultError(fmt.Sprintf(`%v

The authentication layer must inject the X-Semaphore-User-ID header so we can scope task searches to the authenticated caller.

Troubleshooting:
- Ensure requests pass through the auth proxy
- Verify the header value is a UUID (xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx)
- Retry once the header is present`, err)), nil
		}

		if err := authz.CheckProjectPermission(ctx, api, userID, orgID, projectID, schedulerViewPermission); err != nil {
			return shared.ProjectAuthorizationError(err, orgID, projectID, schedulerViewPermission), nil
		}

		limit := req.GetInt("limit", defaultLimit)
		if limit <= 0 {
			limit = defaultLimit
		} else if limit > maxLimit {
			limit = maxLimit
		}

		pageSize, err := utils.IntToInt32(limit, "limit")
		if err != nil {
			return mcp.NewToolResultError(err.Error()), nil
		}

		request := &schedulerpb.ListKeysetRequest{
			ProjectId:      projectID,
			OrganizationId: orgID,
			PageSize:       pageSize,
			PageToken:      cursor,
		}

		callCtx, cancel := context.WithTimeout(ctx, api.CallTimeout())
		defer cancel()

		resp, err := client.ListKeyset(callCtx, request)
		if err != nil {
			logging.ForComponent("rpc").
				WithFields(logrus.Fields{
					"rpc":       "scheduler.ListKeyset",
					"projectId": projectID,
					"limit":     limit,
					"cursor":    cursor,
					"mode":      mode,
				}).
				WithError(err).
				Error("scheduler list RPC failed")
			return mcp.NewToolResultError(fmt.Sprintf(`Task list RPC failed: %v

Possible causes:
- Project does not exist or you lack access rights
- Internal scheduler service is unavailable (retry shortly)
- Network connectivity issues between MCP server and scheduler service

Try reducing the limit or removing filters to see if results return.`, err)), nil
		}

		if err := shared.CheckStatus(resp.GetStatus()); err != nil {
			logging.ForComponent("rpc").
				WithFields(logrus.Fields{
					"rpc":       "scheduler.ListKeyset",
					"projectId": projectID,
				}).
				WithError(err).
				Warn("scheduler list returned non-OK status")
			return mcp.NewToolResultError(fmt.Sprintf(`Request failed: %v

Double-check that:
- project_id is correct
- You have permission to view tasks for this project
- The organization is active and not suspended`, err)), nil
		}

		tasks := make([]taskSummary, 0, len(resp.GetPeriodics()))
		for _, p := range resp.GetPeriodics() {
			if p == nil {
				continue
			}
			tasks = append(tasks, taskSummary{
				ID:           p.GetId(),
				Name:         p.GetName(),
				Description:  p.GetDescription(),
				Branch:       p.GetBranch(),
				PipelineFile: p.GetPipelineFile(),
				Schedule:     p.GetSchedule(),
				Paused:       p.GetPaused(),
				Suspended:    p.GetSuspended(),
				UpdatedAt:    shared.FormatTimestamp(p.GetUpdatedAt()),
			})
		}

		result := listResult{Tasks: tasks}
		if token := strings.TrimSpace(resp.GetNextPageToken()); token != "" {
			result.NextCursor = token
		}

		markdown := formatTasksListMarkdown(result, mode, projectID, orgID, limit)
		markdown = shared.TruncateResponse(markdown, shared.MaxResponseChars)

		tracker.MarkSuccess()
		return &mcp.CallToolResult{
			Content: []mcp.Content{
				mcp.NewTextContent(markdown),
			},
			StructuredContent: result,
		}, nil
	}
}

func formatTasksListMarkdown(result listResult, mode, projectID, orgID string, limit int) string {
	mb := shared.NewMarkdownBuilder()

	header := fmt.Sprintf("Tasks (%d returned)", len(result.Tasks))
	mb.H1(header)

	if len(result.Tasks) == 0 {
		mb.Paragraph("No scheduled tasks found for this project.")
		mb.Paragraph("**Suggestions:**")
		mb.ListItem("Verify the project_id is correct")
		mb.ListItem("Check if the project has any scheduled tasks configured")
		mb.ListItem("Confirm the authenticated user has permission to view this project")
		return mb.String()
	}

	for idx, task := range result.Tasks {
		if idx > 0 {
			mb.Line()
		}

		mb.H2(fmt.Sprintf("Task: %s", task.Name))
		mb.KeyValue("ID", fmt.Sprintf("`%s`", task.ID))

		if task.Branch != "" {
			mb.KeyValue("Branch", task.Branch)
		}
		if task.Schedule != "" {
			mb.KeyValue("Schedule", fmt.Sprintf("`%s`", task.Schedule))
		}

		status := "Active"
		if task.Paused {
			status = "Paused"
		}
		if task.Suspended {
			status = "Suspended"
		}
		mb.KeyValue("Status", status)

		if mode == "detailed" {
			if task.Description != "" {
				mb.KeyValue("Description", task.Description)
			}
			if task.PipelineFile != "" {
				mb.KeyValue("Pipeline File", task.PipelineFile)
			}
			if task.UpdatedAt != "" {
				mb.KeyValue("Updated At", task.UpdatedAt)
			}
		}
	}

	mb.Line()
	if result.NextCursor != "" {
		mb.Paragraph(fmt.Sprintf("More available. Use `cursor=\"%s\"`", result.NextCursor))
	}

	return mb.String()
}
