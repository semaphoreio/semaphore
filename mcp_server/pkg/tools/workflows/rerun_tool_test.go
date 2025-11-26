package workflows

import (
	"context"
	"net/http"
	"strings"
	"testing"
	"time"

	"github.com/mark3labs/mcp-go/mcp"
	"github.com/semaphoreio/semaphore/mcp_server/pkg/feature"
	workflowpb "github.com/semaphoreio/semaphore/mcp_server/pkg/internal_api/plumber_w_f.workflow"
	projecthubpb "github.com/semaphoreio/semaphore/mcp_server/pkg/internal_api/projecthub"
	statuspb "github.com/semaphoreio/semaphore/mcp_server/pkg/internal_api/status"
	support "github.com/semaphoreio/semaphore/mcp_server/test/support"

	code "google.golang.org/genproto/googleapis/rpc/code"
)

func TestRerunWorkflowSuccess(t *testing.T) {
	orgID := "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
	projectID := "11111111-2222-3333-4444-555555555555"
	workflowID := "wf-123"
	userID := "99999999-aaaa-bbbb-cccc-dddddddddddd"

	workflowStub := &support.WorkflowClientStub{
		DescribeResp: &workflowpb.DescribeResponse{
			Status: &statuspb.Status{Code: code.Code_OK},
			Workflow: &workflowpb.WorkflowDetails{
				WfId:           workflowID,
				ProjectId:      projectID,
				OrganizationId: orgID,
			},
		},
		RescheduleResp: &workflowpb.ScheduleResponse{
			Status: &statuspb.Status{Code: code.Code_OK},
			WfId:   "wf-new",
			PplId:  "ppl-new",
		},
	}
	provider := &support.MockProvider{
		WorkflowClient: workflowStub,
		ProjectClient:  &support.ProjectClientStub{Response: support.NewProjectDescribeResponse(orgID, projectID, &projecthubpb.Project_Spec_Repository{})},
		Timeout:        time.Second,
		RBACClient:     support.NewRBACStub(projectRunPermission),
	}

	req := mcp.CallToolRequest{
		Params: mcp.CallToolParams{
			Arguments: map[string]any{
				"workflow_id": workflowID,
			},
		},
	}
	header := http.Header{}
	header.Set("X-Semaphore-User-ID", userID)
	req.Header = header

	res, err := rerunHandler(provider)(context.Background(), req)
	if err != nil {
		toFail(t, "handler error: %v", err)
	}
	result, ok := res.StructuredContent.(rerunResult)
	if !ok {
		toFail(t, "unexpected structured content type: %T", res.StructuredContent)
	}
	if result.WorkflowID != "wf-new" || result.PipelineID != "ppl-new" {
		toFail(t, "unexpected rerun result: %+v", result)
	}
	if result.RerunOf != workflowID {
		toFail(t, "expected rerunOf to match workflow id, got %s", result.RerunOf)
	}
	if workflowStub.LastDescribe == nil || workflowStub.LastDescribe.GetWfId() != workflowID {
		toFail(t, "expected describe call for workflow")
	}
	if workflowStub.LastReschedule == nil {
		toFail(t, "expected reschedule call to be recorded")
	}
	if got := workflowStub.LastReschedule.GetRequesterId(); got != userID {
		toFail(t, "unexpected requester id: %s", got)
	}
}

func TestRerunWorkflowFeatureDisabled(t *testing.T) {
	orgID := "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
	projectID := "11111111-2222-3333-4444-555555555555"
	workflowStub := &support.WorkflowClientStub{
		DescribeResp: &workflowpb.DescribeResponse{
			Status: &statuspb.Status{Code: code.Code_OK},
			Workflow: &workflowpb.WorkflowDetails{
				WfId:           "wf-123",
				ProjectId:      projectID,
				OrganizationId: orgID,
			},
		},
	}
	provider := &support.MockProvider{
		WorkflowClient:  workflowStub,
		ProjectClient:   &support.ProjectClientStub{Response: support.NewProjectDescribeResponse(orgID, projectID, &projecthubpb.Project_Spec_Repository{})},
		Timeout:         time.Second,
		RBACClient:      support.NewRBACStub(projectRunPermission),
		FeaturesService: support.FeatureClientStub{State: feature.Hidden},
	}

	req := mcp.CallToolRequest{
		Params: mcp.CallToolParams{Arguments: map[string]any{
			"workflow_id": "wf-123",
		}},
	}
	header := http.Header{}
	header.Set("X-Semaphore-User-ID", "99999999-aaaa-bbbb-cccc-dddddddddddd")
	req.Header = header

	res, err := rerunHandler(provider)(context.Background(), req)
	if err != nil {
		toFail(t, "handler error: %v", err)
	}
	msg := requireErrorText(t, res)
	if !strings.Contains(strings.ToLower(msg), "disabled") {
		toFail(t, "expected feature disabled message, got %q", msg)
	}
}

func TestRerunWorkflowPermissionDenied(t *testing.T) {
	orgID := "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
	projectID := "11111111-2222-3333-4444-555555555555"
	workflowStub := &support.WorkflowClientStub{
		DescribeResp: &workflowpb.DescribeResponse{
			Status: &statuspb.Status{Code: code.Code_OK},
			Workflow: &workflowpb.WorkflowDetails{
				WfId:           "wf-123",
				ProjectId:      projectID,
				OrganizationId: orgID,
			},
		},
	}
	provider := &support.MockProvider{
		WorkflowClient: workflowStub,
		ProjectClient:  &support.ProjectClientStub{Response: support.NewProjectDescribeResponse(orgID, projectID, &projecthubpb.Project_Spec_Repository{})},
		Timeout:        time.Second,
		RBACClient:     support.NewRBACStub(), // no permissions
	}

	req := mcp.CallToolRequest{
		Params: mcp.CallToolParams{Arguments: map[string]any{
			"workflow_id": "wf-123",
		}},
	}
	header := http.Header{}
	header.Set("X-Semaphore-User-ID", "99999999-aaaa-bbbb-cccc-dddddddddddd")
	req.Header = header

	res, err := rerunHandler(provider)(context.Background(), req)
	if err != nil {
		toFail(t, "handler error: %v", err)
	}
	msg := requireErrorText(t, res)
	if !strings.Contains(msg, "Permission denied while accessing project") {
		toFail(t, "expected permission denied message, got %q", msg)
	}
	if workflowStub.LastReschedule != nil {
		toFail(t, "workflow reschedule should not have been invoked when permission is missing")
	}
}
