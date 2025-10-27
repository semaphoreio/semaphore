package workflows

import (
	"context"
	"net/http"
	"strings"
	"testing"
	"time"

	"github.com/mark3labs/mcp-go/mcp"
	rbacpb "github.com/semaphoreio/semaphore/bootstrapper/pkg/protos/rbac"
	workflowpb "github.com/semaphoreio/semaphore/mcp_server/pkg/internal_api/plumber_w_f.workflow"
	statuspb "github.com/semaphoreio/semaphore/mcp_server/pkg/internal_api/status"
	userpb "github.com/semaphoreio/semaphore/mcp_server/pkg/internal_api/user"
	"github.com/semaphoreio/semaphore/mcp_server/pkg/internalapi"

	"google.golang.org/genproto/googleapis/rpc/code"
	"google.golang.org/grpc"
	"google.golang.org/protobuf/types/known/timestamppb"
)

func TestListWorkflows(t *testing.T) {
	projectID := "11111111-2222-3333-4444-555555555555"
	client := &workflowClientStub{
		listResp: &workflowpb.ListKeysetResponse{
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

	provider := &internalapi.MockProvider{
		WorkflowClient: client,
		Timeout:        time.Second,
		RBACClient:     &allowRBACStub{},
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

	if client.lastList == nil {
		toFail(t, "expected list request to be recorded")
	}
	if got := client.lastList.GetRequesterId(); got != "99999999-aaaa-bbbb-cccc-dddddddddddd" {
		toFail(t, "expected requester to default to user header, got %s", got)
	}

	if got := client.lastList.GetPageSize(); got != 10 {
		toFail(t, "expected page size 10, got %d", got)
	}
}

func TestListWorkflowsWithRequesterOverride(t *testing.T) {
	projectID := "11111111-2222-3333-4444-555555555555"
	requester := "deploy-bot"
	client := &workflowClientStub{
		listResp: &workflowpb.ListKeysetResponse{
			Status:    &statuspb.Status{Code: code.Code_OK},
			Workflows: []*workflowpb.WorkflowDetails{},
		},
	}
	userClient := &userClientStub{
		response: &userpb.User{Id: "00000000-1111-2222-3333-444444444444"},
	}

	provider := &internalapi.MockProvider{
		WorkflowClient: client,
		UserClient:     userClient,
		Timeout:        time.Second,
		RBACClient:     &allowRBACStub{},
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

	if client.lastList == nil {
		toFail(t, "expected list request to be recorded")
	}
	if got := strings.TrimSpace(client.lastList.GetRequesterId()); got != "00000000-1111-2222-3333-444444444444" {
		toFail(t, "expected requester override to propagate, got %s", got)
	}
	if userClient.lastRequest == nil || userClient.lastRequest.GetProvider() == nil {
		toFail(t, "expected user lookup to be recorded")
	}
	if login := userClient.lastRequest.GetProvider().GetLogin(); login != requester {
		toFail(t, "expected user lookup login %s, got %s", requester, login)
	}
}

type workflowClientStub struct {
	workflowpb.WorkflowServiceClient
	listResp *workflowpb.ListKeysetResponse
	listErr  error
	lastList *workflowpb.ListKeysetRequest
}

type allowRBACStub struct {
	rbacpb.RBACClient
}

func (a *allowRBACStub) ListUserPermissions(ctx context.Context, in *rbacpb.ListUserPermissionsRequest, opts ...grpc.CallOption) (*rbacpb.ListUserPermissionsResponse, error) {
	return &rbacpb.ListUserPermissionsResponse{
		UserId:      in.GetUserId(),
		OrgId:       in.GetOrgId(),
		ProjectId:   in.GetProjectId(),
		Permissions: []string{"project.view", "organization.view"},
	}, nil
}

func (s *workflowClientStub) Schedule(context.Context, *workflowpb.ScheduleRequest, ...grpc.CallOption) (*workflowpb.ScheduleResponse, error) {
	panic("not implemented")
}

func (s *workflowClientStub) GetPath(context.Context, *workflowpb.GetPathRequest, ...grpc.CallOption) (*workflowpb.GetPathResponse, error) {
	panic("not implemented")
}

func (s *workflowClientStub) List(context.Context, *workflowpb.ListRequest, ...grpc.CallOption) (*workflowpb.ListResponse, error) {
	panic("not implemented")
}

func (s *workflowClientStub) ListKeyset(ctx context.Context, in *workflowpb.ListKeysetRequest, opts ...grpc.CallOption) (*workflowpb.ListKeysetResponse, error) {
	s.lastList = in
	if s.listErr != nil {
		return nil, s.listErr
	}
	return s.listResp, nil
}

type userClientStub struct {
	userpb.UserServiceClient
	response    *userpb.User
	err         error
	lastRequest *userpb.DescribeByRepositoryProviderRequest
}

func (u *userClientStub) DescribeByRepositoryProvider(ctx context.Context, in *userpb.DescribeByRepositoryProviderRequest, opts ...grpc.CallOption) (*userpb.User, error) {
	u.lastRequest = in
	if u.err != nil {
		return nil, u.err
	}
	if u.response == nil {
		u.response = &userpb.User{Id: "ffffffff-ffff-ffff-ffff-ffffffffffff"}
	}
	return u.response, nil
}

func (s *workflowClientStub) ListGrouped(context.Context, *workflowpb.ListGroupedRequest, ...grpc.CallOption) (*workflowpb.ListGroupedResponse, error) {
	panic("not implemented")
}

func (s *workflowClientStub) ListGroupedKS(context.Context, *workflowpb.ListGroupedKSRequest, ...grpc.CallOption) (*workflowpb.ListGroupedKSResponse, error) {
	panic("not implemented")
}

func (s *workflowClientStub) ListLatestWorkflows(context.Context, *workflowpb.ListLatestWorkflowsRequest, ...grpc.CallOption) (*workflowpb.ListLatestWorkflowsResponse, error) {
	panic("not implemented")
}

func (s *workflowClientStub) Describe(context.Context, *workflowpb.DescribeRequest, ...grpc.CallOption) (*workflowpb.DescribeResponse, error) {
	panic("not implemented")
}

func (s *workflowClientStub) DescribeMany(context.Context, *workflowpb.DescribeManyRequest, ...grpc.CallOption) (*workflowpb.DescribeManyResponse, error) {
	panic("not implemented")
}

func (s *workflowClientStub) Terminate(context.Context, *workflowpb.TerminateRequest, ...grpc.CallOption) (*workflowpb.TerminateResponse, error) {
	panic("not implemented")
}

func (s *workflowClientStub) ListLabels(context.Context, *workflowpb.ListLabelsRequest, ...grpc.CallOption) (*workflowpb.ListLabelsResponse, error) {
	panic("not implemented")
}

func (s *workflowClientStub) Reschedule(context.Context, *workflowpb.RescheduleRequest, ...grpc.CallOption) (*workflowpb.ScheduleResponse, error) {
	panic("not implemented")
}

func (s *workflowClientStub) GetProjectId(context.Context, *workflowpb.GetProjectIdRequest, ...grpc.CallOption) (*workflowpb.GetProjectIdResponse, error) {
	panic("not implemented")
}

func (s *workflowClientStub) Create(context.Context, *workflowpb.CreateRequest, ...grpc.CallOption) (*workflowpb.CreateResponse, error) {
	panic("not implemented")
}

func toFail(t *testing.T, format string, args ...any) {
	t.Helper()
	t.Fatalf(format, args...)
}
