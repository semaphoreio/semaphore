package tasks

import (
	"context"
	"fmt"
	"sort"
	"strconv"
	"strings"
	"unicode/utf8"

	"github.com/mark3labs/mcp-go/mcp"
	"github.com/mark3labs/mcp-go/server"
	"github.com/sirupsen/logrus"

	"github.com/semaphoreio/semaphore/mcp_server/pkg/authz"
	schedulerpb "github.com/semaphoreio/semaphore/mcp_server/pkg/internal_api/periodic_scheduler"
	"github.com/semaphoreio/semaphore/mcp_server/pkg/internalapi"
	"github.com/semaphoreio/semaphore/mcp_server/pkg/logging"
	"github.com/semaphoreio/semaphore/mcp_server/pkg/tools/internal/shared"
)

func runFullDescription() string {
	return `Trigger a scheduled task to run immediately.

Use this when you need to:
- Manually trigger a scheduled task without waiting for the schedule
- Run a task with custom branch or parameters

Required inputs:
- organization_id: Organization UUID that owns the project (required)
- project_id: Project UUID containing the task (required)
- task_id: Task UUID to trigger (required)

Optional inputs:
- branch: Override the task's default branch
- pipeline_file: Override the task's default pipeline file
- parameters: A key/value map of parameters to override (values convert to strings)

The authenticated user must have the 'project.scheduler.run_manually' permission.

Examples:
1. Trigger a task:
   tasks_run(task_id="...", project_id="...", organization_id="...")

2. Trigger with a different branch:
   tasks_run(task_id="...", project_id="...", organization_id="...", branch="develop")

3. Trigger with custom parameters:
   tasks_run(task_id="...", project_id="...", organization_id="...", parameters={"ENV": "staging"})`
}

func newRunTool(name, description string) mcp.Tool {
	return mcp.NewTool(
		name,
		mcp.WithDescription(description),
		mcp.WithString("task_id",
			mcp.Required(),
			mcp.Description("Task UUID to trigger. Format: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx."),
			mcp.Pattern(`^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$`),
		),
		mcp.WithString("project_id",
			mcp.Required(),
			mcp.Description("Project UUID containing the task. Format: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx."),
			mcp.Pattern(`^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$`),
		),
		mcp.WithString("organization_id",
			mcp.Required(),
			mcp.Description("Organization UUID that owns the project."),
			mcp.Pattern(`^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$`),
		),
		mcp.WithString("branch",
			mcp.Description("Optional branch to override the task's default branch."),
		),
		mcp.WithString("pipeline_file",
			mcp.Description("Optional pipeline file path to override the task's default."),
		),
		mcp.WithObject("parameters",
			mcp.Description("Optional key/value parameters to pass to the task run."),
			mcp.AdditionalProperties(map[string]any{
				"oneOf": []any{
					map[string]any{"type": "string"},
					map[string]any{"type": "number"},
					map[string]any{"type": "boolean"},
					map[string]any{"type": "null"},
				},
			}),
		),
		mcp.WithIdempotentHintAnnotation(false),
	)
}

type runResult struct {
	TaskID       string `json:"task_id"`
	TaskName     string `json:"task_name"`
	WorkflowID   string `json:"workflow_id"`
	Branch       string `json:"branch"`
	PipelineFile string `json:"pipeline_file"`
	TriggeredAt  string `json:"triggered_at"`
}

func runHandler(api internalapi.Provider) server.ToolHandlerFunc {
	return func(ctx context.Context, req mcp.CallToolRequest) (*mcp.CallToolResult, error) {
		orgIDRaw, err := req.RequireString("organization_id")
		if err != nil {
			return mcp.NewToolResultError(`Missing required argument: organization_id. Provide the organization UUID.`), nil
		}
		orgID := strings.TrimSpace(orgIDRaw)
		if err := shared.ValidateUUID(orgID, "organization_id"); err != nil {
			return mcp.NewToolResultError(err.Error()), nil
		}

		if err := shared.EnsureWriteToolsFeature(ctx, api, orgID); err != nil {
			return mcp.NewToolResultError(err.Error()), nil
		}

		tracker := shared.TrackToolExecution(ctx, runToolName, orgID)
		defer tracker.Cleanup()

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

		projectIDRaw, err := req.RequireString("project_id")
		if err != nil {
			return mcp.NewToolResultError(`Missing required argument: project_id. Provide the project UUID (xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx).`), nil
		}
		projectID := strings.TrimSpace(projectIDRaw)
		if err := shared.ValidateUUID(projectID, "project_id"); err != nil {
			return mcp.NewToolResultError(err.Error()), nil
		}

		userID := strings.ToLower(strings.TrimSpace(req.Header.Get("X-Semaphore-User-ID")))
		if err := shared.ValidateUUID(userID, "x-semaphore-user-id header"); err != nil {
			return mcp.NewToolResultError(fmt.Sprintf(`%v

The authentication layer must inject the X-Semaphore-User-ID header so we can authorize task runs.`, err)), nil
		}

		if err := authz.CheckProjectPermission(ctx, api, userID, orgID, projectID, schedulerRunPermission); err != nil {
			return shared.ProjectAuthorizationError(err, orgID, projectID, schedulerRunPermission), nil
		}

		branch, err := shared.SanitizeBranch(req.GetString("branch", ""), "branch")
		if err != nil {
			return mcp.NewToolResultError(err.Error()), nil
		}

		pipelineFile := strings.TrimSpace(req.GetString("pipeline_file", ""))
		if err := validatePipelineFile(pipelineFile, "pipeline_file"); err != nil {
			return mcp.NewToolResultError(err.Error()), nil
		}

		parameters, err := extractParameters(req.GetArguments()["parameters"])
		if err != nil {
			return mcp.NewToolResultError(err.Error()), nil
		}

		pbParams, err := buildParameters(parameters)
		if err != nil {
			return mcp.NewToolResultError(err.Error()), nil
		}

		request := &schedulerpb.RunNowRequest{
			Id:             taskID,
			OrganizationId: orgID,
			ProjectId:      projectID,
			RequesterId:    userID,
			Branch:         branch,
			PipelineFile:   pipelineFile,
			Parameters:     pbParams,
		}

		callCtx, cancel := context.WithTimeout(ctx, api.CallTimeout())
		defer cancel()

		resp, err := client.RunNow(callCtx, request)
		if err != nil {
			logging.ForComponent("rpc").
				WithFields(logrus.Fields{
					"rpc":       "scheduler.RunNow",
					"taskId":    taskID,
					"projectId": projectID,
					"orgId":     orgID,
				}).
				WithError(err).
				Error("scheduler RunNow RPC failed")
			return mcp.NewToolResultError(fmt.Sprintf(`Task run failed: %v

Possible causes:
- Task does not exist or is suspended
- Project repository configuration is invalid
- Internal scheduler service is unavailable (retry shortly)`, err)), nil
		}

		if err := shared.CheckStatus(resp.GetStatus()); err != nil {
			return mcp.NewToolResultError(fmt.Sprintf("Task run failed: %v", err)), nil
		}

		result := runResult{
			TaskID:       resp.GetPeriodicId(),
			TaskName:     resp.GetPeriodicName(),
			WorkflowID:   resp.GetWorkflowId(),
			Branch:       resp.GetBranch(),
			PipelineFile: resp.GetPipelineFile(),
			TriggeredAt:  shared.FormatTimestamp(resp.GetTriggeredAt()),
		}

		markdown := formatRunMarkdown(result)
		markdown = shared.TruncateResponse(markdown, shared.MaxResponseChars)

		tracker.MarkSuccess()
		return &mcp.CallToolResult{
			Content:           []mcp.Content{mcp.NewTextContent(markdown)},
			StructuredContent: result,
		}, nil
	}
}

func validatePipelineFile(value, field string) error {
	value = strings.TrimSpace(value)
	if value == "" {
		return nil
	}
	length := utf8.RuneCountInString(value)
	if length > 512 {
		return fmt.Errorf("%s must not exceed 512 characters", field)
	}
	for _, r := range value {
		if r < 32 || r == 127 {
			return fmt.Errorf("%s contains control characters", field)
		}
		if r == '\\' {
			return fmt.Errorf("%s must not contain backslashes", field)
		}
	}
	if strings.Contains(value, "..") {
		return fmt.Errorf("%s must not contain '..' sequences", field)
	}
	if strings.HasPrefix(value, "/") {
		return fmt.Errorf("%s must be a relative path", field)
	}
	return nil
}

func extractParameters(raw any) (map[string]any, error) {
	if raw == nil {
		return nil, nil
	}
	params, ok := raw.(map[string]any)
	if !ok {
		return nil, fmt.Errorf("parameters must be a key/value map with string keys")
	}
	return params, nil
}

func buildParameters(params map[string]any) ([]*schedulerpb.Parameter, error) {
	if len(params) == 0 {
		return nil, nil
	}
	names := make([]string, 0, len(params))
	for name := range params {
		names = append(names, name)
	}
	sort.Strings(names)
	result := make([]*schedulerpb.Parameter, 0, len(names))
	for _, name := range names {
		clean := strings.TrimSpace(name)
		if clean == "" {
			return nil, fmt.Errorf("parameter names must not be empty")
		}
		if err := validateParameterName(clean); err != nil {
			return nil, err
		}
		value, err := parameterValueToString(params[name])
		if err != nil {
			return nil, err
		}
		result = append(result, &schedulerpb.Parameter{Name: clean, Value: value})
	}
	return result, nil
}

func validateParameterName(name string) error {
	if utf8.RuneCountInString(name) > 128 {
		return fmt.Errorf("parameter names must not exceed 128 characters")
	}
	for _, r := range name {
		if r < 32 || r == 127 {
			return fmt.Errorf("parameter %q contains control characters", name)
		}
	}
	// Parameter names should start with a letter or underscore
	if len(name) > 0 {
		first := rune(name[0])
		if !((first >= 'a' && first <= 'z') || (first >= 'A' && first <= 'Z') || first == '_') {
			return fmt.Errorf("parameter %q must start with a letter or underscore", name)
		}
	}
	return nil
}

func parameterValueToString(value any) (string, error) {
	switch v := value.(type) {
	case nil:
		return "", nil
	case string:
		return v, nil
	case bool:
		if v {
			return "true", nil
		}
		return "false", nil
	case float64:
		return strconv.FormatFloat(v, 'f', -1, 64), nil
	case int:
		return strconv.Itoa(v), nil
	case int32:
		return strconv.FormatInt(int64(v), 10), nil
	case int64:
		return strconv.FormatInt(v, 10), nil
	case uint32:
		return strconv.FormatUint(uint64(v), 10), nil
	case uint64:
		return strconv.FormatUint(v, 10), nil
	default:
		return "", fmt.Errorf("parameters values must be strings, numbers, booleans, or null")
	}
}

func formatRunMarkdown(result runResult) string {
	mb := shared.NewMarkdownBuilder()
	mb.H1("Task Triggered")

	if result.TaskName != "" {
		mb.KeyValue("Task Name", result.TaskName)
	}
	if result.TaskID != "" {
		mb.KeyValue("Task ID", fmt.Sprintf("`%s`", result.TaskID))
	}
	if result.WorkflowID != "" {
		mb.KeyValue("Workflow ID", fmt.Sprintf("`%s`", result.WorkflowID))
	}
	if result.Branch != "" {
		mb.KeyValue("Branch", result.Branch)
	}
	if result.PipelineFile != "" {
		mb.KeyValue("Pipeline File", result.PipelineFile)
	}
	if result.TriggeredAt != "" {
		mb.KeyValue("Triggered At", result.TriggeredAt)
	}

	return mb.String()
}
