package jobs

import (
	"context"
	"net/http"
	"testing"
	"time"

	"github.com/mark3labs/mcp-go/mcp"
	rbacpb "github.com/semaphoreio/semaphore/bootstrapper/pkg/protos/rbac"
	loghubpb "github.com/semaphoreio/semaphore/mcp_server/pkg/internal_api/loghub"
	loghub2pb "github.com/semaphoreio/semaphore/mcp_server/pkg/internal_api/loghub2"
	responsepb "github.com/semaphoreio/semaphore/mcp_server/pkg/internal_api/response_status"
	jobpb "github.com/semaphoreio/semaphore/mcp_server/pkg/internal_api/server_farm.job"
	"github.com/semaphoreio/semaphore/mcp_server/pkg/internalapi"

	"google.golang.org/grpc"
	"google.golang.org/protobuf/types/known/timestamppb"
)

func TestDescribeJob(t *testing.T) {
	jobID := "11111111-2222-3333-4444-555555555555"
	orgID := "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
	client := &jobClientStub{
		describeResp: &jobpb.DescribeResponse{
			Status: &responsepb.ResponseStatus{Code: responsepb.ResponseStatus_OK},
			Job: &jobpb.Job{
				Id:             jobID,
				Name:           "Build",
				PplId:          "ppl-1",
				ProjectId:      "proj-1",
				OrganizationId: orgID,
				FailureReason:  "",
				Timeline: &jobpb.Job_Timeline{
					CreatedAt: timestamppb.New(time.Unix(1700000000, 0)),
				},
			},
		},
	}

	provider := &internalapi.MockProvider{JobClient: client, Timeout: time.Second, RBACClient: &allowRBACStub{}}
	handler := describeHandler(provider)
	req := mcp.CallToolRequest{Params: mcp.CallToolParams{Arguments: map[string]any{
		"organization_id": orgID,
		"job_id":          jobID,
	}}}
	header := http.Header{}
	header.Set("X-Semaphore-User-ID", "99999999-aaaa-bbbb-cccc-dddddddddddd")
	req.Header = header

	res, err := handler(context.Background(), req)
	if err != nil {
		toFail(t, "handler error: %v", err)
	}

	result, ok := res.StructuredContent.(jobSummary)
	if !ok {
		toFail(t, "unexpected structured content type: %T", res.StructuredContent)
	}

	if result.ID != jobID || result.PipelineID != "ppl-1" {
		toFail(t, "unexpected job summary: %+v", result)
	}
}

func TestFetchHostedLogs(t *testing.T) {
	jobID := "99999999-aaaa-bbbb-cccc-dddddddddddd"
	jobClient := &jobClientStub{
		describeResp: &jobpb.DescribeResponse{
			Status: &responsepb.ResponseStatus{Code: responsepb.ResponseStatus_OK},
			Job: &jobpb.Job{
				Id:             jobID,
				ProjectId:      "proj-1",
				OrganizationId: "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
				SelfHosted:     false,
			},
		},
	}
	loghubClient := &loghubClientStub{
		resp: &loghubpb.GetLogEventsResponse{
			Status: &responsepb.ResponseStatus{Code: responsepb.ResponseStatus_OK},
			Events: []string{"line1", "line2"},
			Final:  false,
		},
	}

	provider := &internalapi.MockProvider{
		JobClient:    jobClient,
		LoghubClient: loghubClient,
		RBACClient:   &allowRBACStub{},
		Timeout:      time.Second,
	}

	handler := logsHandler(provider)
	req := mcp.CallToolRequest{Params: mcp.CallToolParams{Arguments: map[string]any{
		"organization_id": "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
		"job_id":          jobID,
		"cursor":          "5",
	}}}
	header := http.Header{}
	header.Set("X-Semaphore-User-ID", "99999999-aaaa-bbbb-cccc-dddddddddddd")
	req.Header = header

	res, err := handler(context.Background(), req)
	if err != nil {
		toFail(t, "handler error: %v", err)
	}

	result, ok := res.StructuredContent.(logsResult)
	if !ok {
		toFail(t, "unexpected structured content type: %T", res.StructuredContent)
	}

	if result.Source != loghubSource || result.NextCursor != "7" || len(result.Preview) != 2 {
		toFail(t, "unexpected log result: %+v", result)
	}

	if loghubClient.lastRequest == nil || loghubClient.lastRequest.GetStartingLine() != 5 {
		toFail(t, "unexpected loghub request: %+v", loghubClient.lastRequest)
	}
}

func TestFetchSelfHostedLogs(t *testing.T) {
	jobID := "88888888-7777-6666-5555-444444444444"
	jobClient := &jobClientStub{
		describeResp: &jobpb.DescribeResponse{
			Status: &responsepb.ResponseStatus{Code: responsepb.ResponseStatus_OK},
			Job: &jobpb.Job{
				Id:             jobID,
				ProjectId:      "proj-1",
				OrganizationId: "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
				SelfHosted:     true,
			},
		},
	}
	loghub2Client := &loghub2ClientStub{
		resp: &loghub2pb.GenerateTokenResponse{Token: "token", Type: loghub2pb.TokenType_PULL},
	}

	provider := &internalapi.MockProvider{
		JobClient:     jobClient,
		Loghub2Client: loghub2Client,
		RBACClient:    &allowRBACStub{},
		Timeout:       time.Second,
	}

	handler := logsHandler(provider)
	req := mcp.CallToolRequest{Params: mcp.CallToolParams{Arguments: map[string]any{
		"organization_id": "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
		"job_id":          jobID,
	}}}
	header := http.Header{}
	header.Set("X-Semaphore-User-ID", "99999999-aaaa-bbbb-cccc-dddddddddddd")
	req.Header = header

	res, err := handler(context.Background(), req)
	if err != nil {
		toFail(t, "handler error: %v", err)
	}

	result, ok := res.StructuredContent.(logsResult)
	if !ok {
		toFail(t, "unexpected structured content type: %T", res.StructuredContent)
	}

	if result.Source != loghub2Source || result.Token != "token" || result.TokenTtlSeconds != loghub2TokenDuration {
		toFail(t, "unexpected loghub2 response: %+v", result)
	}

	if loghub2Client.lastRequest == nil || loghub2Client.lastRequest.GetJobId() != jobID {
		toFail(t, "unexpected loghub2 request: %+v", loghub2Client.lastRequest)
	}
}

type jobClientStub struct {
	jobpb.JobServiceClient
	describeResp *jobpb.DescribeResponse
	describeErr  error
	lastDescribe *jobpb.DescribeRequest
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

func (s *jobClientStub) Describe(ctx context.Context, in *jobpb.DescribeRequest, opts ...grpc.CallOption) (*jobpb.DescribeResponse, error) {
	s.lastDescribe = in
	if s.describeErr != nil {
		return nil, s.describeErr
	}
	return s.describeResp, nil
}

func (s *jobClientStub) List(context.Context, *jobpb.ListRequest, ...grpc.CallOption) (*jobpb.ListResponse, error) {
	panic("not implemented")
}

func (s *jobClientStub) ListDebugSessions(context.Context, *jobpb.ListDebugSessionsRequest, ...grpc.CallOption) (*jobpb.ListDebugSessionsResponse, error) {
	panic("not implemented")
}

func (s *jobClientStub) Count(context.Context, *jobpb.CountRequest, ...grpc.CallOption) (*jobpb.CountResponse, error) {
	panic("not implemented")
}

func (s *jobClientStub) CountByState(context.Context, *jobpb.CountByStateRequest, ...grpc.CallOption) (*jobpb.CountByStateResponse, error) {
	panic("not implemented")
}

func (s *jobClientStub) Stop(context.Context, *jobpb.StopRequest, ...grpc.CallOption) (*jobpb.StopResponse, error) {
	panic("not implemented")
}

func (s *jobClientStub) TotalExecutionTime(context.Context, *jobpb.TotalExecutionTimeRequest, ...grpc.CallOption) (*jobpb.TotalExecutionTimeResponse, error) {
	panic("not implemented")
}

func (s *jobClientStub) GetAgentPayload(context.Context, *jobpb.GetAgentPayloadRequest, ...grpc.CallOption) (*jobpb.GetAgentPayloadResponse, error) {
	panic("not implemented")
}

func (s *jobClientStub) CanDebug(context.Context, *jobpb.CanDebugRequest, ...grpc.CallOption) (*jobpb.CanDebugResponse, error) {
	panic("not implemented")
}

func (s *jobClientStub) CanAttach(context.Context, *jobpb.CanAttachRequest, ...grpc.CallOption) (*jobpb.CanAttachResponse, error) {
	panic("not implemented")
}

func (s *jobClientStub) Create(context.Context, *jobpb.CreateRequest, ...grpc.CallOption) (*jobpb.CreateResponse, error) {
	panic("not implemented")
}

type loghubClientStub struct {
	loghubpb.LoghubClient
	resp        *loghubpb.GetLogEventsResponse
	err         error
	lastRequest *loghubpb.GetLogEventsRequest
}

func (s *loghubClientStub) GetLogEvents(ctx context.Context, in *loghubpb.GetLogEventsRequest, opts ...grpc.CallOption) (*loghubpb.GetLogEventsResponse, error) {
	s.lastRequest = in
	if s.err != nil {
		return nil, s.err
	}
	return s.resp, nil
}

type loghub2ClientStub struct {
	loghub2pb.Loghub2Client
	resp        *loghub2pb.GenerateTokenResponse
	err         error
	lastRequest *loghub2pb.GenerateTokenRequest
}

func (s *loghub2ClientStub) GenerateToken(ctx context.Context, in *loghub2pb.GenerateTokenRequest, opts ...grpc.CallOption) (*loghub2pb.GenerateTokenResponse, error) {
	s.lastRequest = in
	if s.err != nil {
		return nil, s.err
	}
	return s.resp, nil
}

func toFail(t *testing.T, format string, args ...any) {
	t.Helper()
	t.Fatalf(format, args...)
}
