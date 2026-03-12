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
)

func describeFullDescription() string {
	return `Get detailed information about a scheduled task (periodic).

Use this when you need to answer:
- "Show me the details of task X"
- "What parameters does this task have?"
- "When did this task last run?"
- "What is the trigger history for this task?"

- organization_id: identify which organization context (required)
- task_id: the UUID of the task to describe (required)

Response modes:
- summary (default): task details, status, schedule
- detailed: adds recent trigger history and parameters

Examples:
1. Get task details:
   tasks_describe(task_id="...", organization_id="...")

2. Get detailed trigger history:
   tasks_describe(task_id="...", organization_id="...", mode="detailed")

Next steps:
- Call tasks_run(task_id="...") to trigger this task immediately
- Call workflows_search() to find workflows triggered by this task`
}

func newDescribeTool(name, description string) mcp.Tool {
	return mcp.NewTool(
		name,
		mcp.WithDescription(description),
		mcp.WithString("task_id",
			mcp.Required(),
			mcp.Description("Task UUID to describe. Format: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx."),
			mcp.Pattern(`^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$`),
		),
		mcp.WithString("organization_id",
			mcp.Required(),
			mcp.Description("Organization UUID associated with the task. Keep this consistent across subsequent tool calls."),
			mcp.Pattern(`^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$`),
		),
		mcp.WithString("mode",
			mcp.Description("Response detail. Use 'summary' for compact output; 'detailed' adds trigger history and parameters."),
			mcp.Enum("summary", "detailed"),
			mcp.DefaultString("summary"),
		),
		mcp.WithReadOnlyHintAnnotation(true),
		mcp.WithIdempotentHintAnnotation(true),
		mcp.WithOpenWorldHintAnnotation(true),
	)
}

type taskParameter struct {
	Name        string `json:"name"`
	Value       string `json:"value,omitempty"`
	Required    bool   `json:"required"`
	Description string `json:"description,omitempty"`
}

type taskDetail struct {
	ID           string          `json:"id"`
	Name         string          `json:"name"`
	Description  string          `json:"description,omitempty"`
	ProjectID    string          `json:"project_id"`
	Branch       string          `json:"branch"`
	PipelineFile string          `json:"pipeline_file"`
	Schedule     string          `json:"schedule,omitempty"`
	Parameters   []taskParameter `json:"parameters,omitempty"`
	Paused       bool            `json:"paused"`
	Suspended    bool            `json:"suspended"`
	CreatedAt    string          `json:"created_at,omitempty"`
	UpdatedAt    string          `json:"updated_at,omitempty"`
}

type trigger struct {
	TriggeredAt  string `json:"triggered_at"`
	WorkflowID   string `json:"workflow_id,omitempty"`
	Status       string `json:"status"`
	Branch       string `json:"branch"`
	PipelineFile string `json:"pipeline_file"`
	ErrorMessage string `json:"error_message,omitempty"`
}

type describeResult struct {
	Task           taskDetail `json:"task"`
	RecentTriggers []trigger  `json:"recent_triggers,omitempty"`
}

func describeHandler(api internalapi.Provider) server.ToolHandlerFunc {
	return func(ctx context.Context, req mcp.CallToolRequest) (*mcp.CallToolResult, error) {
		client := api.Scheduler()
		if client == nil {
			return mcp.NewToolResultError(missingSchedulerError), nil
		}

		taskIDRaw, err := req.RequireString("task_id")
		if err != nil {
			return mcp.NewToolResultError(`Missing required argument: task_id. Provide the task UUID (xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx).`), nil
		}
		taskID := strings.TrimSpace(taskIDRaw)
		if err := shared.ValidateUUID(taskID, "task_id"); err != nil {
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

		tracker := shared.TrackToolExecution(ctx, describeToolName, orgID)
		defer tracker.Cleanup()

		if err := shared.EnsureReadToolsFeature(ctx, api, orgID); err != nil {
			return mcp.NewToolResultError(err.Error()), nil
		}

		mode, err := shared.NormalizeMode(req.GetString("mode", "summary"))
		if err != nil {
			return mcp.NewToolResultError(fmt.Sprintf("Invalid mode parameter: %v", err)), nil
		}

		userID := strings.ToLower(strings.TrimSpace(req.Header.Get("X-Semaphore-User-ID")))
		if err := shared.ValidateUUID(userID, "x-semaphore-user-id header"); err != nil {
			return mcp.NewToolResultError(fmt.Sprintf(`%v

The authentication layer must inject the X-Semaphore-User-ID header so we can authorize task access.`, err)), nil
		}

		request := &schedulerpb.DescribeRequest{
			Id:             taskID,
			OrganizationId: orgID,
		}

		callCtx, cancel := context.WithTimeout(ctx, api.CallTimeout())
		defer cancel()

		resp, err := client.Describe(callCtx, request)
		if err != nil {
			logging.ForComponent("rpc").
				WithFields(logrus.Fields{
					"rpc":    "scheduler.Describe",
					"taskId": taskID,
					"mode":   mode,
				}).
				WithError(err).
				Error("scheduler describe RPC failed")
			return mcp.NewToolResultError(fmt.Sprintf(`Task describe RPC failed: %v

Possible causes:
- Task does not exist or you lack access rights
- Internal scheduler service is unavailable (retry shortly)
- Network connectivity issues between MCP server and scheduler service`, err)), nil
		}

		if err := shared.CheckStatus(resp.GetStatus()); err != nil {
			logging.ForComponent("rpc").
				WithFields(logrus.Fields{
					"rpc":    "scheduler.Describe",
					"taskId": taskID,
				}).
				WithError(err).
				Warn("scheduler describe returned non-OK status")
			return mcp.NewToolResultError(fmt.Sprintf(`Request failed: %v

Double-check that:
- task_id is correct
- You have permission to view this task
- The organization is active and not suspended`, err)), nil
		}

		periodic := resp.GetPeriodic()
		if periodic == nil {
			return mcp.NewToolResultError("Task not found or access denied."), nil
		}

		// Check permission on the project that owns this task
		projectID := periodic.GetProjectId()
		if projectID != "" {
			if err := authz.CheckProjectPermission(ctx, api, userID, orgID, projectID, schedulerViewPermission); err != nil {
				return shared.ProjectAuthorizationError(err, orgID, projectID, schedulerViewPermission), nil
			}
		}

		// Build parameters list
		var params []taskParameter
		for _, p := range periodic.GetParameters() {
			if p == nil {
				continue
			}
			params = append(params, taskParameter{
				Name:        p.GetName(),
				Value:       p.GetValue(),
				Required:    p.GetRequired(),
				Description: p.GetDescription(),
			})
		}

		detail := taskDetail{
			ID:           periodic.GetId(),
			Name:         periodic.GetName(),
			Description:  periodic.GetDescription(),
			ProjectID:    periodic.GetProjectId(),
			Branch:       periodic.GetBranch(),
			PipelineFile: periodic.GetPipelineFile(),
			Schedule:     periodic.GetSchedule(),
			Parameters:   params,
			Paused:       periodic.GetPaused(),
			Suspended:    periodic.GetSuspended(),
			CreatedAt:    shared.FormatTimestamp(periodic.GetCreatedAt()),
			UpdatedAt:    shared.FormatTimestamp(periodic.GetUpdatedAt()),
		}

		// Build triggers list
		var triggers []trigger
		for _, t := range resp.GetRecentTriggers() {
			if t == nil {
				continue
			}
			triggers = append(triggers, trigger{
				TriggeredAt:  shared.FormatTimestamp(t.GetTriggeredAt()),
				WorkflowID:   t.GetWorkflowId(),
				Status:       triggerStatusToString(t.GetStatus()),
				Branch:       t.GetBranch(),
				PipelineFile: t.GetPipelineFile(),
				ErrorMessage: t.GetErrorMessage(),
			})
		}

		result := describeResult{
			Task:           detail,
			RecentTriggers: triggers,
		}

		markdown := formatTaskDescribeMarkdown(result, mode)
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

func triggerStatusToString(status schedulerpb.TriggerStatus) string {
	switch status {
	case schedulerpb.TriggerStatus_TRIGGER_STATUS_SCHEDULED:
		return "scheduled"
	case schedulerpb.TriggerStatus_TRIGGER_STATUS_RUNNING:
		return "running"
	case schedulerpb.TriggerStatus_TRIGGER_STATUS_PASSED:
		return "passed"
	case schedulerpb.TriggerStatus_TRIGGER_STATUS_FAILED:
		return "failed"
	case schedulerpb.TriggerStatus_TRIGGER_STATUS_STOPPED:
		return "stopped"
	default:
		return "unknown"
	}
}

func formatTaskDescribeMarkdown(result describeResult, mode string) string {
	mb := shared.NewMarkdownBuilder()

	task := result.Task
	mb.H1(fmt.Sprintf("Task: %s", task.Name))

	mb.KeyValue("ID", fmt.Sprintf("`%s`", task.ID))
	if task.ProjectID != "" {
		mb.KeyValue("Project ID", fmt.Sprintf("`%s`", task.ProjectID))
	}

	status := "Active"
	if task.Paused {
		status = "Paused"
	}
	if task.Suspended {
		status = "Suspended"
	}
	mb.KeyValue("Status", status)

	if task.Branch != "" {
		mb.KeyValue("Branch", task.Branch)
	}
	if task.PipelineFile != "" {
		mb.KeyValue("Pipeline File", task.PipelineFile)
	}
	if task.Schedule != "" {
		mb.KeyValue("Schedule", fmt.Sprintf("`%s`", task.Schedule))
	}

	if task.Description != "" {
		mb.Line()
		mb.Paragraph(fmt.Sprintf("**Description:** %s", task.Description))
	}

	if mode == "detailed" {
		if task.CreatedAt != "" {
			mb.KeyValue("Created At", task.CreatedAt)
		}
		if task.UpdatedAt != "" {
			mb.KeyValue("Updated At", task.UpdatedAt)
		}

		if len(task.Parameters) > 0 {
			mb.Line()
			mb.H2("Parameters")
			for _, p := range task.Parameters {
				reqStr := ""
				if p.Required {
					reqStr = " (required)"
				}
				if p.Description != "" {
					mb.ListItem(fmt.Sprintf("`%s`%s: %s", p.Name, reqStr, p.Description))
				} else {
					mb.ListItem(fmt.Sprintf("`%s`%s", p.Name, reqStr))
				}
			}
		}

		if len(result.RecentTriggers) > 0 {
			mb.Line()
			mb.H2("Recent Triggers")
			for _, t := range result.RecentTriggers {
				mb.Line()
				mb.KeyValue("Triggered At", t.TriggeredAt)
				mb.KeyValue("Status", t.Status)
				if t.WorkflowID != "" {
					mb.KeyValue("Workflow ID", fmt.Sprintf("`%s`", t.WorkflowID))
				}
				if t.Branch != "" {
					mb.KeyValue("Branch", t.Branch)
				}
				if t.ErrorMessage != "" {
					mb.KeyValue("Error", t.ErrorMessage)
				}
			}
		}
	}

	return mb.String()
}
