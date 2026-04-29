package workflows

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"strings"
	"testing"
	"time"

	"github.com/mark3labs/mcp-go/mcp"
	auditlog "github.com/semaphoreio/semaphore/mcp_server/pkg/audit"
	"github.com/semaphoreio/semaphore/mcp_server/pkg/feature"
	auditpb "github.com/semaphoreio/semaphore/mcp_server/pkg/internal_api/audit"
	workflowpb "github.com/semaphoreio/semaphore/mcp_server/pkg/internal_api/plumber_w_f.workflow"
	projecthubpb "github.com/semaphoreio/semaphore/mcp_server/pkg/internal_api/projecthub"
	statuspb "github.com/semaphoreio/semaphore/mcp_server/pkg/internal_api/status"
	"github.com/semaphoreio/semaphore/mcp_server/pkg/logging"
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

func TestRerunWorkflowEmitsWorkflowRebuildAuditEvent(t *testing.T) {
	orgID := "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
	projectID := "11111111-2222-3333-4444-555555555555"
	workflowID := "wf-123"
	userID := "99999999-aaaa-bbbb-cccc-dddddddddddd"
	branchName := "main"
	commitSHA := "abc1234"

	workflowStub := &support.WorkflowClientStub{
		DescribeResp: &workflowpb.DescribeResponse{
			Status: &statuspb.Status{Code: code.Code_OK},
			Workflow: &workflowpb.WorkflowDetails{
				WfId:           workflowID,
				ProjectId:      projectID,
				OrganizationId: orgID,
				BranchName:     branchName,
				CommitSha:      commitSHA,
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
		FeaturesService: support.FeatureClientStub{
			States: map[string]feature.State{
				"mcp_server_write_tools": feature.Enabled,
				"audit_logs":             feature.Enabled,
			},
		},
	}

	publisher := &auditPublisherStub{}
	restore := auditlog.SetPublisherForTests(publisher)
	defer restore()

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
	if res == nil || res.IsError {
		toFail(t, "expected successful response, got %#v", res)
	}

	if len(publisher.events) != 1 {
		toFail(t, "expected one audit event, got %d", len(publisher.events))
	}

	event := publisher.events[0]
	if event.GetResource() != auditpb.Event_Workflow {
		toFail(t, "expected Workflow resource, got %v", event.GetResource())
	}
	if event.GetOperation() != auditpb.Event_Rebuild {
		toFail(t, "expected Rebuild operation, got %v", event.GetOperation())
	}
	if event.GetUserId() != userID {
		toFail(t, "expected user_id %s, got %s", userID, event.GetUserId())
	}
	if event.GetOrgId() != orgID {
		toFail(t, "expected org_id %s, got %s", orgID, event.GetOrgId())
	}
	if event.GetResourceName() != workflowID {
		toFail(t, "expected resource_name %s, got %s", workflowID, event.GetResourceName())
	}

	meta := map[string]string{}
	if err := json.Unmarshal([]byte(event.GetMetadata()), &meta); err != nil {
		toFail(t, "failed to decode metadata JSON: %v", err)
	}
	if meta["project_id"] != projectID {
		toFail(t, "expected project_id %s, got %s", projectID, meta["project_id"])
	}
	if meta["branch_name"] != branchName {
		toFail(t, "expected branch_name %s, got %s", branchName, meta["branch_name"])
	}
	if meta["workflow_id"] != workflowID {
		toFail(t, "expected workflow_id %s, got %s", workflowID, meta["workflow_id"])
	}
	if meta["commit_sha"] != commitSHA {
		toFail(t, "expected commit_sha %s, got %s", commitSHA, meta["commit_sha"])
	}
}

func TestRerunWorkflowFailsWhenAuditPublishFails(t *testing.T) {
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
				BranchName:     "main",
				CommitSha:      "abc1234",
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
		FeaturesService: support.FeatureClientStub{
			States: map[string]feature.State{
				"mcp_server_write_tools": feature.Enabled,
				"audit_logs":             feature.Enabled,
			},
		},
	}

	publisher := &auditPublisherStub{err: errors.New("amqp down")}
	restore := auditlog.SetPublisherForTests(publisher)
	defer restore()

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

	msg := requireErrorText(t, res)
	if !strings.Contains(msg, "Audit logging failed") {
		toFail(t, "expected audit failure message, got %q", msg)
	}
	if workflowStub.LastReschedule != nil {
		toFail(t, "expected rerun to stop before reschedule when audit publish fails")
	}
}

func TestRerunWorkflowFailsWhenAuditFeatureCheckFails(t *testing.T) {
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
				BranchName:     "main",
				CommitSha:      "abc1234",
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
		FeaturesService: support.FeatureClientStub{
			States: map[string]feature.State{
				"mcp_server_write_tools": feature.Enabled,
				"audit_logs":             feature.Enabled,
			},
			StateErrors: map[string]error{
				"audit_logs": errors.New("feature service timeout"),
			},
		},
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

	msg := requireErrorText(t, res)
	if !strings.Contains(msg, "Unable to verify audit logging availability") {
		toFail(t, "expected audit feature check failure message, got %q", msg)
	}
	if workflowStub.LastReschedule != nil {
		toFail(t, "expected rerun to stop before reschedule when audit feature check fails")
	}
}

func TestRerunWorkflowEmitsAuditWhenRescheduleFails(t *testing.T) {
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
				BranchName:     "main",
				CommitSha:      "abc1234",
			},
		},
		RescheduleErr: errors.New("reschedule boom"),
	}

	provider := &support.MockProvider{
		WorkflowClient: workflowStub,
		ProjectClient:  &support.ProjectClientStub{Response: support.NewProjectDescribeResponse(orgID, projectID, &projecthubpb.Project_Spec_Repository{})},
		Timeout:        time.Second,
		RBACClient:     support.NewRBACStub(projectRunPermission),
		FeaturesService: support.FeatureClientStub{
			States: map[string]feature.State{
				"mcp_server_write_tools": feature.Enabled,
				"audit_logs":             feature.Enabled,
			},
		},
	}

	publisher := &auditPublisherStub{}
	restore := auditlog.SetPublisherForTests(publisher)
	defer restore()

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
	if res == nil || !res.IsError {
		toFail(t, "expected error response, got %#v", res)
	}

	if len(publisher.events) != 1 {
		toFail(t, "expected one audit event when reschedule fails, got %d", len(publisher.events))
	}

	event := publisher.events[0]
	if event.GetResource() != auditpb.Event_Workflow {
		toFail(t, "expected Workflow resource, got %v", event.GetResource())
	}
	if event.GetOperation() != auditpb.Event_Rebuild {
		toFail(t, "expected Rebuild operation, got %v", event.GetOperation())
	}
}

func TestRerunWorkflowSkipsAuditPublishWhenAuditLogsFeatureDisabled(t *testing.T) {
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
		FeaturesService: support.FeatureClientStub{
			State: feature.Hidden,
			States: map[string]feature.State{
				"mcp_server_write_tools": feature.Enabled,
				"audit_logs":             feature.Hidden,
			},
		},
	}

	publisher := &auditPublisherStub{}
	restore := auditlog.SetPublisherForTests(publisher)
	defer restore()

	logs := captureLoggerOutput(t)

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
	if res == nil || res.IsError {
		toFail(t, "expected successful response, got %#v", res)
	}

	if len(publisher.events) != 0 {
		toFail(t, "expected no published audit events, got %d", len(publisher.events))
	}

	output := logs.String()
	if !strings.Contains(output, "AuditLog") {
		toFail(t, "expected stdout audit log, got %q", output)
	}
	if !strings.Contains(output, userID) {
		toFail(t, "expected stdout audit log to include user_id %s, got %q", userID, output)
	}
	if !strings.Contains(output, orgID) {
		toFail(t, "expected stdout audit log to include org_id %s, got %q", orgID, output)
	}
	if !strings.Contains(output, workflowID) {
		toFail(t, "expected stdout audit log to include workflow_id %s, got %q", workflowID, output)
	}
}

type auditPublisherStub struct {
	events []*auditpb.Event
	err    error
}

func (s *auditPublisherStub) Publish(_ context.Context, event *auditpb.Event) error {
	s.events = append(s.events, event)
	return s.err
}

func captureLoggerOutput(t *testing.T) *bytes.Buffer {
	t.Helper()

	logger := logging.Logger()
	var buf bytes.Buffer
	previous := logger.Out
	logger.SetOutput(&buf)
	t.Cleanup(func() {
		logger.SetOutput(previous)
	})

	return &buf
}
