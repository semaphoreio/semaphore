package workflows

import (
	"context"
	"fmt"
	"strings"

	"github.com/google/uuid"
	"github.com/mark3labs/mcp-go/mcp"
	"github.com/mark3labs/mcp-go/server"
	"github.com/sirupsen/logrus"

	"github.com/semaphoreio/semaphore/mcp_server/pkg/authz"
	workflowpb "github.com/semaphoreio/semaphore/mcp_server/pkg/internal_api/plumber_w_f.workflow"
	"github.com/semaphoreio/semaphore/mcp_server/pkg/internalapi"
	"github.com/semaphoreio/semaphore/mcp_server/pkg/logging"
	"github.com/semaphoreio/semaphore/mcp_server/pkg/tools/internal/shared"
)

func rerunFullDescription() string {
	return `Rerun an existing workflow.

Use this when you need to:
- Rerun a previously completed or failed workflow
- Restart a workflow without changing its parameters

Required inputs:
- workflow_id: ID of the workflow to rerun

The authenticated user must have permission to rerun workflows for the originating project.`
}

func newRerunTool(name, description string) mcp.Tool {
	return mcp.NewTool(
		name,
		mcp.WithDescription(description),
		mcp.WithString(
			"workflow_id",
			mcp.Required(),
			mcp.Description("Workflow ID to rerun."),
		),
		mcp.WithIdempotentHintAnnotation(false),
	)
}

func rerunHandler(api internalapi.Provider) server.ToolHandlerFunc {
	return func(ctx context.Context, req mcp.CallToolRequest) (*mcp.CallToolResult, error) {
		workflowClient := api.Workflow()
		if workflowClient == nil {
			return mcp.NewToolResultError(missingWorkflowError), nil
		}

		workflowIDRaw, err := req.RequireString("workflow_id")
		if err != nil {
			return mcp.NewToolResultError(`Missing required argument: workflow_id. Provide the workflow ID to rerun.`), nil
		}
		workflowID, err := sanitizeWorkflowID(workflowIDRaw, "workflow_id")
		if err != nil {
			return mcp.NewToolResultError(err.Error()), nil
		}

		userID := strings.ToLower(strings.TrimSpace(req.Header.Get("X-Semaphore-User-ID")))
		if err := shared.ValidateUUID(userID, "x-semaphore-user-id header"); err != nil {
			return mcp.NewToolResultError(fmt.Sprintf(`%v

The authentication layer must inject the X-Semaphore-User-ID header so we can authorize workflow reruns.`, err)), nil
		}

		describeCtx, cancelDescribe := context.WithTimeout(ctx, api.CallTimeout())
		defer cancelDescribe()

		describeResp, err := workflowClient.Describe(describeCtx, &workflowpb.DescribeRequest{WfId: workflowID})
		if err != nil {
			logging.ForComponent("rpc").
				WithFields(logrus.Fields{
					"rpc":  "workflow.Describe",
					"wfId": workflowID,
				}).
				WithError(err).
				Error("workflow describe RPC failed")
			return mcp.NewToolResultError("Unable to load workflow details. Confirm the workflow exists and try again."), nil
		}

		if err := shared.CheckStatus(describeResp.GetStatus()); err != nil {
			return mcp.NewToolResultError(fmt.Sprintf("Unable to load workflow details: %v", err)), nil
		}

		workflow := describeResp.GetWorkflow()
		if workflow == nil {
			return mcp.NewToolResultError("Workflow details are missing from the response. Please retry."), nil
		}

		orgID := strings.TrimSpace(workflow.GetOrganizationId())
		if err := shared.ValidateUUID(orgID, "workflow organization_id"); err != nil {
			return mcp.NewToolResultError("Unable to determine workflow organization. Please try again later."), nil
		}

		projectID := strings.TrimSpace(workflow.GetProjectId())
		if err := shared.ValidateUUID(projectID, "workflow project_id"); err != nil {
			return mcp.NewToolResultError("Unable to determine workflow project. Please try again later."), nil
		}

		if err := shared.EnsureWriteToolsFeature(ctx, api, orgID); err != nil {
			return mcp.NewToolResultError(err.Error()), nil
		}

		tracker := shared.TrackToolExecution(ctx, rerunToolName, orgID)
		defer tracker.Cleanup()

		if err := authz.CheckProjectPermission(ctx, api, userID, orgID, projectID, projectRunPermission); err != nil {
			return shared.ProjectAuthorizationError(err, orgID, projectID, projectRunPermission), nil
		}

		rescheduleCtx, cancelReschedule := context.WithTimeout(ctx, api.CallTimeout())
		defer cancelReschedule()

		requestToken := uuid.NewString()

		rescheduleReq := &workflowpb.RescheduleRequest{
			WfId:         workflowID,
			RequesterId:  userID,
			RequestToken: requestToken,
		}

		rescheduleResp, err := workflowClient.Reschedule(rescheduleCtx, rescheduleReq)
		if err != nil {
			logging.ForComponent("rpc").
				WithFields(logrus.Fields{
					"rpc":       "workflow.Reschedule",
					"wfId":      workflowID,
					"projectId": projectID,
					"orgId":     orgID,
				}).
				WithError(err).
				Error("workflow reschedule RPC failed")
			return mcp.NewToolResultError("Workflow rerun failed. Confirm the workflow exists and try again."), nil
		}

		if err := shared.CheckStatus(rescheduleResp.GetStatus()); err != nil {
			return mcp.NewToolResultError(fmt.Sprintf("Workflow rerun failed: %v", err)), nil
		}

		result := rerunResult{
			WorkflowID: strings.TrimSpace(rescheduleResp.GetWfId()),
			PipelineID: strings.TrimSpace(rescheduleResp.GetPplId()),
			RerunOf:    workflowID,
			ProjectID:  projectID,
			OrgID:      orgID,
		}

		markdown := formatRerunMarkdown(result)
		markdown = shared.TruncateResponse(markdown, shared.MaxResponseChars)

		tracker.MarkSuccess()
		return &mcp.CallToolResult{
			Content:           []mcp.Content{mcp.NewTextContent(markdown)},
			StructuredContent: result,
		}, nil
	}
}

func sanitizeWorkflowID(raw, field string) (string, error) {
	value := strings.TrimSpace(raw)
	if value == "" {
		return "", fmt.Errorf("%s is required", field)
	}
	if strings.ContainsAny(value, " \t\r\n") {
		return "", fmt.Errorf("%s must not contain whitespace", field)
	}
	if len(value) > 128 {
		return "", fmt.Errorf("%s must not exceed 128 characters", field)
	}
	return value, nil
}

func formatRerunMarkdown(result rerunResult) string {
	mb := shared.NewMarkdownBuilder()
	mb.H1("Workflow Rerun Scheduled")
	if result.WorkflowID != "" {
		mb.KeyValue("Workflow ID", fmt.Sprintf("`%s`", result.WorkflowID))
	}
	if result.PipelineID != "" {
		mb.KeyValue("Initial Pipeline", fmt.Sprintf("`%s`", result.PipelineID))
	}
	if result.RerunOf != "" {
		mb.KeyValue("Rerun Of", fmt.Sprintf("`%s`", result.RerunOf))
	}
	if result.ProjectID != "" {
		mb.KeyValue("Project ID", fmt.Sprintf("`%s`", result.ProjectID))
	}
	if result.OrgID != "" {
		mb.KeyValue("Organization ID", fmt.Sprintf("`%s`", result.OrgID))
	}
	return mb.String()
}
