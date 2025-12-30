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
	statuspb "github.com/semaphoreio/semaphore/mcp_server/pkg/internal_api/status"
	userpb "github.com/semaphoreio/semaphore/mcp_server/pkg/internal_api/user"
	support "github.com/semaphoreio/semaphore/mcp_server/test/support"

	"google.golang.org/genproto/googleapis/rpc/code"
	"google.golang.org/protobuf/types/known/timestamppb"
)

func TestListWorkflows_FeatureFlagDisabled(t *testing.T) {
	req := mcp.CallToolRequest{Params: mcp.CallToolParams{Arguments: map[string]any{
		"organization_id": "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
		"project_id":      "11111111-2222-3333-4444-555555555555",
	}}}
	header := http.Header{}
	header.Set("X-Semaphore-User-ID", "99999999-aaaa-bbbb-cccc-dddddddddddd")
	req.Header = header

	provider := &support.MockProvider{
		FeaturesService: support.FeatureClientStub{State: feature.Hidden},
		Timeout:         time.Second,
		WorkflowClient:  &support.WorkflowClientStub{},
		RBACClient:      support.NewRBACStub("project.view"),
	}

	res, err := listHandler(provider)(context.Background(), req)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	msg := requireErrorText(t, res)
	if !strings.Contains(strings.ToLower(msg), "disabled") {
		t.Fatalf("expected disabled feature error, got %q", msg)
	}
}

func TestListWorkflows(t *testing.T) {
	projectID := "11111111-2222-3333-4444-555555555555"
	client := &support.WorkflowClientStub{
		ListResp: &workflowpb.ListKeysetResponse{
			Status: &statuspb.Status{Code: code.Code_OK},
			Workflows: []*workflowpb.WorkflowDetails{
				{
					WfId:           "wf-123",
					ProjectId:      projectID,
					BranchName:     "main",
					CommitSha:      "abc123",
					CreatedAt:      timestamppb.New(time.Unix(1700000000, 0)),
					TriggeredBy:    workflowpb.TriggeredBy_MANUAL_RUN,
					OrganizationId: "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
				},
			},
			NextPageToken: "cursor",
		},
	}

	provider := &support.MockProvider{
		WorkflowClient: client,
		Timeout:        time.Second,
		RBACClient:     support.NewRBACStub("project.view"),
	}

	handler := listHandler(provider)
	req := mcp.CallToolRequest{
		Params: mcp.CallToolParams{
			Arguments: map[string]any{
				"project_id":      projectID,
				"organization_id": "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
				"limit":           10,
			},
		},
	}
	header := http.Header{}
	header.Set("X-Semaphore-User-ID", "99999999-aaaa-bbbb-cccc-dddddddddddd")
	req.Header = header

	res, err := handler(context.Background(), req)
	if err != nil {
		toFail(t, "handler error: %v", err)
	}

	result, ok := res.StructuredContent.(listResult)
	if !ok {
		toFail(t, "unexpected structured content type: %T", res.StructuredContent)
	}

	if len(result.Workflows) != 1 {
		toFail(t, "expected 1 workflow, got %d", len(result.Workflows))
	}

	wf := result.Workflows[0]
	if wf.ID != "wf-123" || wf.ProjectID != projectID || wf.TriggeredBy != "manual_run" {
		toFail(t, "unexpected workflow summary: %+v", wf)
	}

	if result.NextCursor != "cursor" {
		toFail(t, "expected next cursor 'cursor', got %q", result.NextCursor)
	}

	if client.LastList == nil {
		toFail(t, "expected list request to be recorded")
	}
	if got := client.LastList.GetRequesterId(); got != "99999999-aaaa-bbbb-cccc-dddddddddddd" {
		toFail(t, "expected requester to default to user header, got %s", got)
	}

	if got := client.LastList.GetPageSize(); got != 10 {
		toFail(t, "expected page size 10, got %d", got)
	}
}

func TestListWorkflowsWithRequesterOverride(t *testing.T) {
	projectID := "11111111-2222-3333-4444-555555555555"
	requester := "deploy-bot"
	client := &support.WorkflowClientStub{
		ListResp: &workflowpb.ListKeysetResponse{
			Status:    &statuspb.Status{Code: code.Code_OK},
			Workflows: []*workflowpb.WorkflowDetails{},
		},
	}
	userClient := &support.UserClientStub{
		Response: &userpb.User{Id: "00000000-1111-2222-3333-444444444444"},
	}

	provider := &support.MockProvider{
		WorkflowClient: client,
		UserClient:     userClient,
		Timeout:        time.Second,
		RBACClient:     support.NewRBACStub("project.view"),
	}

	req := mcp.CallToolRequest{
		Params: mcp.CallToolParams{
			Arguments: map[string]any{
				"project_id":        projectID,
				"organization_id":   "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
				"my_workflows_only": false,
				"requester":         requester,
			},
		},
	}
	header := http.Header{}
	header.Set("X-Semaphore-User-ID", "99999999-aaaa-bbbb-cccc-dddddddddddd")
	req.Header = header

	_, err := listHandler(provider)(context.Background(), req)
	if err != nil {
		toFail(t, "handler error: %v", err)
	}

	if client.LastList == nil {
		toFail(t, "expected list request to be recorded")
	}
	if got := strings.TrimSpace(client.LastList.GetRequesterId()); got != "00000000-1111-2222-3333-444444444444" {
		toFail(t, "expected requester override to propagate, got %s", got)
	}
	if userClient.LastRequest == nil || userClient.LastRequest.GetProvider() == nil {
		toFail(t, "expected user lookup to be recorded")
	}
	if login := userClient.LastRequest.GetProvider().GetLogin(); login != requester {
		toFail(t, "expected user lookup login %s, got %s", requester, login)
	}
}

func TestListWorkflowsPermissionDenied(t *testing.T) {
	projectID := "11111111-2222-3333-4444-555555555555"
	client := &support.WorkflowClientStub{}
	rbac := support.NewRBACStub()

	provider := &support.MockProvider{
		WorkflowClient: client,
		Timeout:        time.Second,
		RBACClient:     rbac,
	}

	req := mcp.CallToolRequest{
		Params: mcp.CallToolParams{
			Arguments: map[string]any{
				"project_id":      projectID,
				"organization_id": "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
			},
		},
	}
	header := http.Header{}
	header.Set("X-Semaphore-User-ID", "99999999-aaaa-bbbb-cccc-dddddddddddd")
	req.Header = header

	res, err := listHandler(provider)(context.Background(), req)
	if err != nil {
		toFail(t, "handler error: %v", err)
	}

	msg := requireErrorText(t, res)
	if !strings.Contains(msg, `Permission denied while accessing project`) {
		toFail(t, "expected permission denied message, got %q", msg)
	}
	if client.LastList != nil {
		toFail(t, "expected no workflow RPC call, got %+v", client.LastList)
	}
	if len(rbac.LastRequests) != 1 {
		toFail(t, "expected one RBAC request, got %d", len(rbac.LastRequests))
	}
}

func TestListWorkflowsRBACUnavailable(t *testing.T) {
	projectID := "11111111-2222-3333-4444-555555555555"
	client := &support.WorkflowClientStub{}

	provider := &support.MockProvider{
		WorkflowClient: client,
		Timeout:        time.Second,
	}

	req := mcp.CallToolRequest{
		Params: mcp.CallToolParams{
			Arguments: map[string]any{
				"project_id":      projectID,
				"organization_id": "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
			},
		},
	}
	header := http.Header{}
	header.Set("X-Semaphore-User-ID", "99999999-aaaa-bbbb-cccc-dddddddddddd")
	req.Header = header

	res, err := listHandler(provider)(context.Background(), req)
	if err != nil {
		toFail(t, "handler error: %v", err)
	}

	msg := requireErrorText(t, res)
	if !strings.Contains(msg, "Authorization service is not configured") {
		toFail(t, "expected RBAC unavailable message, got %q", msg)
	}
	if client.LastList != nil {
		toFail(t, "expected no workflow RPC call, got %+v", client.LastList)
	}
}

func TestListWorkflowsScopeMismatchOrganization(t *testing.T) {
	projectID := "11111111-2222-3333-4444-555555555555"
	client := &support.WorkflowClientStub{
		ListResp: &workflowpb.ListKeysetResponse{
			Status: &statuspb.Status{Code: code.Code_OK},
			Workflows: []*workflowpb.WorkflowDetails{
				{
					WfId:           "wf-123",
					ProjectId:      projectID,
					OrganizationId: "bbbbbbbb-cccc-dddd-eeee-ffffffffffff",
				},
			},
		},
	}
	rbac := support.NewRBACStub("project.view")

	provider := &support.MockProvider{
		WorkflowClient: client,
		Timeout:        time.Second,
		RBACClient:     rbac,
	}

	req := mcp.CallToolRequest{
		Params: mcp.CallToolParams{
			Arguments: map[string]any{
				"project_id":      projectID,
				"organization_id": "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
			},
		},
	}
	header := http.Header{}
	header.Set("X-Semaphore-User-ID", "99999999-aaaa-bbbb-cccc-dddddddddddd")
	req.Header = header

	res, err := listHandler(provider)(context.Background(), req)
	if err != nil {
		toFail(t, "handler error: %v", err)
	}

	msg := requireErrorText(t, res)
	if !strings.Contains(msg, "outside the authorized organization scope") {
		toFail(t, "expected organization scope mismatch message, got %q", msg)
	}
}

func TestListWorkflowsScopeMismatchProject(t *testing.T) {
	projectID := "11111111-2222-3333-4444-555555555555"
	client := &support.WorkflowClientStub{
		ListResp: &workflowpb.ListKeysetResponse{
			Status: &statuspb.Status{Code: code.Code_OK},
			Workflows: []*workflowpb.WorkflowDetails{
				{
					WfId:           "wf-123",
					ProjectId:      "different-project",
					OrganizationId: "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
				},
			},
		},
	}
	rbac := support.NewRBACStub("project.view")

	provider := &support.MockProvider{
		WorkflowClient: client,
		Timeout:        time.Second,
		RBACClient:     rbac,
	}

	req := mcp.CallToolRequest{
		Params: mcp.CallToolParams{
			Arguments: map[string]any{
				"project_id":      projectID,
				"organization_id": "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
			},
		},
	}
	header := http.Header{}
	header.Set("X-Semaphore-User-ID", "99999999-aaaa-bbbb-cccc-dddddddddddd")
	req.Header = header

	res, err := listHandler(provider)(context.Background(), req)
	if err != nil {
		toFail(t, "handler error: %v", err)
	}

	msg := requireErrorText(t, res)
	if !strings.Contains(msg, "outside the authorized project scope") {
		toFail(t, "expected project scope mismatch message, got %q", msg)
	}
}
