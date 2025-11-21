package jobs

import (
	"context"
	"fmt"
	"net/http"
	"strings"
	"testing"
	"time"

	"github.com/mark3labs/mcp-go/mcp"
	"github.com/semaphoreio/semaphore/mcp_server/pkg/feature"
	loghubpb "github.com/semaphoreio/semaphore/mcp_server/pkg/internal_api/loghub"
	loghub2pb "github.com/semaphoreio/semaphore/mcp_server/pkg/internal_api/loghub2"
	rbacpb "github.com/semaphoreio/semaphore/mcp_server/pkg/internal_api/rbac"
	responsepb "github.com/semaphoreio/semaphore/mcp_server/pkg/internal_api/response_status"
	jobpb "github.com/semaphoreio/semaphore/mcp_server/pkg/internal_api/server_farm.job"
	support "github.com/semaphoreio/semaphore/mcp_server/test/support"

	"google.golang.org/grpc"
	"google.golang.org/protobuf/types/known/timestamppb"
)

func TestDescribeJob_FeatureFlagDisabled(t *testing.T) {
	orgID := "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
	req := mcp.CallToolRequest{Params: mcp.CallToolParams{Arguments: map[string]any{
		"organization_id": orgID,
		"job_id":          "11111111-2222-3333-4444-555555555555",
	}}}
	header := http.Header{}
	header.Set("X-Semaphore-User-ID", "99999999-aaaa-bbbb-cccc-dddddddddddd")
	req.Header = header

	provider := &support.MockProvider{
		FeaturesService: support.FeatureClientStub{State: feature.Hidden},
		Timeout:         time.Second,
	}

	res, err := describeHandler(provider)(context.Background(), req)
	if err != nil {
		toFail(t, "unexpected error: %v", err)
	}

	msg := requireErrorText(t, res)
	if !strings.Contains(strings.ToLower(msg), "disabled") {
		toFail(t, "expected disabled feature error, got %q", msg)
	}
}

func TestLogsHandler_FeatureFlagDisabled(t *testing.T) {
	orgID := "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
	req := mcp.CallToolRequest{Params: mcp.CallToolParams{Arguments: map[string]any{
		"organization_id": orgID,
		"job_id":          "11111111-2222-3333-4444-555555555555",
	}}}
	header := http.Header{}
	header.Set("X-Semaphore-User-ID", "99999999-aaaa-bbbb-cccc-dddddddddddd")
	req.Header = header

	provider := &support.MockProvider{
		FeaturesService: support.FeatureClientStub{State: feature.Hidden},
		Timeout:         time.Second,
		LoghubClient:    &loghubClientStub{},
		Loghub2Client:   &loghub2ClientStub{},
		JobClient: &jobClientStub{
			describeResp: &jobpb.DescribeResponse{
				Status: &responsepb.ResponseStatus{Code: responsepb.ResponseStatus_OK},
				Job: &jobpb.Job{
					Id:             "11111111-2222-3333-4444-555555555555",
					ProjectId:      "proj-1",
					OrganizationId: orgID,
				},
			},
		},
	}

	res, err := logsHandler(provider)(context.Background(), req)
	if err != nil {
		toFail(t, "unexpected error: %v", err)
	}

	msg := requireErrorText(t, res)
	if !strings.Contains(strings.ToLower(msg), "disabled") {
		toFail(t, "expected disabled feature error, got %q", msg)
	}
}

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

	provider := &support.MockProvider{JobClient: client, Timeout: time.Second, RBACClient: newRBACStub("project.view", "organization.view")}
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

func TestDescribeJobPermissionDenied(t *testing.T) {
	jobID := "11111111-2222-3333-4444-555555555555"
	orgID := "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
	client := &jobClientStub{
		describeResp: &jobpb.DescribeResponse{
			Status: &responsepb.ResponseStatus{Code: responsepb.ResponseStatus_OK},
			Job: &jobpb.Job{
				Id:             jobID,
				PplId:          "ppl-1",
				ProjectId:      "proj-1",
				OrganizationId: orgID,
			},
		},
	}
	rbac := newRBACStub("organization.view")
	provider := &support.MockProvider{JobClient: client, Timeout: time.Second, RBACClient: rbac}

	req := mcp.CallToolRequest{Params: mcp.CallToolParams{Arguments: map[string]any{
		"organization_id": orgID,
		"job_id":          jobID,
	}}}
	header := http.Header{}
	header.Set("X-Semaphore-User-ID", "99999999-aaaa-bbbb-cccc-dddddddddddd")
	req.Header = header

	res, err := describeHandler(provider)(context.Background(), req)
	if err != nil {
		toFail(t, "handler error: %v", err)
	}

	msg := requireErrorText(t, res)
	if !strings.Contains(msg, `Permission denied while accessing project proj-1`) {
		toFail(t, "expected project denial message, got %q", msg)
	}
	if len(rbac.lastRequests) != 1 {
		toFail(t, "expected one RBAC request, got %d", len(rbac.lastRequests))
	}
	if got := rbac.lastRequests[0].GetProjectId(); got != "proj-1" {
		toFail(t, "expected RBAC project proj-1, got %s", got)
	}
	if got := rbac.lastRequests[0].GetOrgId(); got != orgID {
		toFail(t, "expected RBAC org %s, got %s", orgID, got)
	}
}

func TestDescribeJobRBACUnavailable(t *testing.T) {
	jobID := "11111111-2222-3333-4444-555555555555"
	orgID := "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
	client := &jobClientStub{
		describeResp: &jobpb.DescribeResponse{
			Status: &responsepb.ResponseStatus{Code: responsepb.ResponseStatus_OK},
			Job: &jobpb.Job{
				Id:             jobID,
				PplId:          "ppl-1",
				ProjectId:      "proj-1",
				OrganizationId: orgID,
			},
		},
	}

	provider := &support.MockProvider{JobClient: client, Timeout: time.Second}
	req := mcp.CallToolRequest{Params: mcp.CallToolParams{Arguments: map[string]any{
		"organization_id": orgID,
		"job_id":          jobID,
	}}}
	header := http.Header{}
	header.Set("X-Semaphore-User-ID", "99999999-aaaa-bbbb-cccc-dddddddddddd")
	req.Header = header

	res, err := describeHandler(provider)(context.Background(), req)
	if err != nil {
		toFail(t, "handler error: %v", err)
	}

	msg := requireErrorText(t, res)
	if !strings.Contains(msg, "Authorization service is not configured") {
		toFail(t, "expected RBAC unavailable message, got %q", msg)
	}
}

func TestDescribeJobScopeMismatchOrganization(t *testing.T) {
	jobID := "11111111-2222-3333-4444-555555555555"
	orgID := "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
	client := &jobClientStub{
		describeResp: &jobpb.DescribeResponse{
			Status: &responsepb.ResponseStatus{Code: responsepb.ResponseStatus_OK},
			Job: &jobpb.Job{
				Id:             jobID,
				PplId:          "ppl-1",
				ProjectId:      "proj-1",
				OrganizationId: "bbbbbbbb-cccc-dddd-eeee-ffffffffffff",
			},
		},
	}
	rbac := newRBACStub("project.view")
	provider := &support.MockProvider{JobClient: client, Timeout: time.Second, RBACClient: rbac}

	req := mcp.CallToolRequest{Params: mcp.CallToolParams{Arguments: map[string]any{
		"organization_id": orgID,
		"job_id":          jobID,
	}}}
	header := http.Header{}
	header.Set("X-Semaphore-User-ID", "99999999-aaaa-bbbb-cccc-dddddddddddd")
	req.Header = header

	res, err := describeHandler(provider)(context.Background(), req)
	if err != nil {
		toFail(t, "handler error: %v", err)
	}

	msg := requireErrorText(t, res)
	if !strings.Contains(msg, "outside the authorized organization scope") {
		toFail(t, "expected organization scope mismatch message, got %q", msg)
	}
	if len(rbac.lastRequests) != 0 {
		toFail(t, "expected no RBAC calls, got %d", len(rbac.lastRequests))
	}
}

func TestDescribeJobScopeMismatchMissingProject(t *testing.T) {
	jobID := "11111111-2222-3333-4444-555555555555"
	orgID := "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
	client := &jobClientStub{
		describeResp: &jobpb.DescribeResponse{
			Status: &responsepb.ResponseStatus{Code: responsepb.ResponseStatus_OK},
			Job: &jobpb.Job{
				Id:             jobID,
				PplId:          "ppl-1",
				ProjectId:      "",
				OrganizationId: orgID,
			},
		},
	}
	rbac := newRBACStub("project.view")
	provider := &support.MockProvider{JobClient: client, Timeout: time.Second, RBACClient: rbac}

	req := mcp.CallToolRequest{Params: mcp.CallToolParams{Arguments: map[string]any{
		"organization_id": orgID,
		"job_id":          jobID,
	}}}
	header := http.Header{}
	header.Set("X-Semaphore-User-ID", "99999999-aaaa-bbbb-cccc-dddddddddddd")
	req.Header = header

	res, err := describeHandler(provider)(context.Background(), req)
	if err != nil {
		toFail(t, "handler error: %v", err)
	}

	msg := requireErrorText(t, res)
	if !strings.Contains(msg, "outside the authorized project scope") {
		toFail(t, "expected project scope mismatch message, got %q", msg)
	}
	if len(rbac.lastRequests) != 0 {
		toFail(t, "expected no RBAC calls, got %d", len(rbac.lastRequests))
	}
}

func TestFetchHostedLogsPagination(t *testing.T) {
	const orgID = "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
	const jobID = "99999999-aaaa-bbbb-cccc-dddddddddddd"

	jobClient := &jobClientStub{
		describeResp: &jobpb.DescribeResponse{
			Status: &responsepb.ResponseStatus{Code: responsepb.ResponseStatus_OK},
			Job: &jobpb.Job{
				Id:             jobID,
				ProjectId:      "proj-1",
				OrganizationId: orgID,
				SelfHosted:     false,
			},
		},
	}

	makeEvents := func(start, end int) []string {
		events := make([]string, end-start)
		for i := start; i < end; i++ {
			events[i-start] = fmt.Sprintf("line-%d", i)
		}
		return events
	}

	testCases := []struct {
		name           string
		cursor         string
		events         []string
		expectedStart  int
		expectedLen    int
		expectedFirst  string
		expectedLast   string
		expectedCursor string
		truncated      bool
	}{
		{
			name:           "initialRequestTruncatesToNewestLines",
			cursor:         "",
			events:         makeEvents(0, 500),
			expectedStart:  500 - maxLogPreviewLines,
			expectedLen:    maxLogPreviewLines,
			expectedFirst:  fmt.Sprintf("line-%d", 500-maxLogPreviewLines),
			expectedLast:   "line-499",
			expectedCursor: fmt.Sprintf("%d", 500-(2*maxLogPreviewLines)),
			truncated:      true,
		},
		{
			name:           "initialRequestShortLog",
			cursor:         "",
			events:         makeEvents(0, 100),
			expectedStart:  0,
			expectedLen:    100,
			expectedFirst:  "line-0",
			expectedLast:   "line-99",
			expectedCursor: "",
			truncated:      false,
		},
		{
			name:           "cursorInMiddleReturnsOlderChunk",
			cursor:         "150",
			events:         makeEvents(150, 500),
			expectedStart:  150,
			expectedLen:    maxLogPreviewLines,
			expectedFirst:  "line-150",
			expectedLast:   "line-349",
			expectedCursor: "0",
			truncated:      true,
		},
		{
			name:           "cursorAtBeginningHasNoFurtherPages",
			cursor:         "0",
			events:         makeEvents(0, 500),
			expectedStart:  0,
			expectedLen:    maxLogPreviewLines,
			expectedFirst:  "line-0",
			expectedLast:   "line-199",
			expectedCursor: "",
			truncated:      true,
		},
	}

	for _, tc := range testCases {
		tc := tc
		t.Run(tc.name, func(t *testing.T) {
			loghubClient := &loghubClientStub{
				resp: &loghubpb.GetLogEventsResponse{
					Status: &responsepb.ResponseStatus{Code: responsepb.ResponseStatus_OK},
					Events: tc.events,
					Final:  false,
				},
			}

			provider := &support.MockProvider{
				JobClient:    jobClient,
				LoghubClient: loghubClient,
				RBACClient:   newRBACStub("project.view"),
				Timeout:      time.Second,
			}

			handler := logsHandler(provider)
			args := map[string]any{
				"organization_id": orgID,
				"job_id":          jobID,
			}
			if tc.cursor != "" {
				args["cursor"] = tc.cursor
			}
			req := mcp.CallToolRequest{Params: mcp.CallToolParams{Arguments: args}}
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

			if result.StartLine != tc.expectedStart {
				toFail(t, "expected start line %d, got %d", tc.expectedStart, result.StartLine)
			}
			if len(result.Preview) != tc.expectedLen {
				toFail(t, "expected preview length %d, got %d", tc.expectedLen, len(result.Preview))
			}
			if tc.expectedLen > 0 {
				if got := result.Preview[0]; got != tc.expectedFirst {
					toFail(t, "unexpected first preview line: %s", got)
				}
				if got := result.Preview[len(result.Preview)-1]; got != tc.expectedLast {
					toFail(t, "unexpected last preview line: %s", got)
				}
			}
			if result.NextCursor != tc.expectedCursor {
				toFail(t, "expected next cursor %q, got %q", tc.expectedCursor, result.NextCursor)
			}
			if result.PreviewTruncated != tc.truncated {
				toFail(t, "expected truncated=%v, got %v", tc.truncated, result.PreviewTruncated)
			}
		})
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

	provider := &support.MockProvider{
		JobClient:     jobClient,
		Loghub2Client: loghub2Client,
		RBACClient:    newRBACStub("project.view"),
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

func TestLogsPermissionDenied(t *testing.T) {
	jobID := "99999999-aaaa-bbbb-cccc-dddddddddddd"
	orgID := "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
	jobClient := &jobClientStub{
		describeResp: &jobpb.DescribeResponse{
			Status: &responsepb.ResponseStatus{Code: responsepb.ResponseStatus_OK},
			Job: &jobpb.Job{
				Id:             jobID,
				ProjectId:      "proj-1",
				OrganizationId: orgID,
				SelfHosted:     false,
			},
		},
	}
	loghubClient := &loghubClientStub{}
	rbac := newRBACStub()

	provider := &support.MockProvider{
		JobClient:    jobClient,
		LoghubClient: loghubClient,
		RBACClient:   rbac,
		Timeout:      time.Second,
	}

	req := mcp.CallToolRequest{Params: mcp.CallToolParams{Arguments: map[string]any{
		"organization_id": orgID,
		"job_id":          jobID,
	}}}
	header := http.Header{}
	header.Set("X-Semaphore-User-ID", "99999999-aaaa-bbbb-cccc-dddddddddddd")
	req.Header = header

	res, err := logsHandler(provider)(context.Background(), req)
	if err != nil {
		toFail(t, "handler error: %v", err)
	}

	msg := requireErrorText(t, res)
	if !strings.Contains(msg, `Permission denied while accessing project proj-1`) {
		toFail(t, "expected project denial message, got %q", msg)
	}
	if len(rbac.lastRequests) != 1 {
		toFail(t, "expected one RBAC request, got %d", len(rbac.lastRequests))
	}
	if loghubClient.lastRequest != nil {
		toFail(t, "expected no loghub call, got %+v", loghubClient.lastRequest)
	}
}

func TestLogsScopeMismatchOrganization(t *testing.T) {
	jobID := "99999999-aaaa-bbbb-cccc-dddddddddddd"
	orgID := "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
	jobClient := &jobClientStub{
		describeResp: &jobpb.DescribeResponse{
			Status: &responsepb.ResponseStatus{Code: responsepb.ResponseStatus_OK},
			Job: &jobpb.Job{
				Id:             jobID,
				ProjectId:      "proj-1",
				OrganizationId: "bbbbbbbb-cccc-dddd-eeee-ffffffffffff",
				SelfHosted:     false,
			},
		},
	}
	loghubClient := &loghubClientStub{}
	rbac := newRBACStub("project.view")

	provider := &support.MockProvider{
		JobClient:    jobClient,
		LoghubClient: loghubClient,
		RBACClient:   rbac,
		Timeout:      time.Second,
	}

	req := mcp.CallToolRequest{Params: mcp.CallToolParams{Arguments: map[string]any{
		"organization_id": orgID,
		"job_id":          jobID,
	}}}
	header := http.Header{}
	header.Set("X-Semaphore-User-ID", "99999999-aaaa-bbbb-cccc-dddddddddddd")
	req.Header = header

	res, err := logsHandler(provider)(context.Background(), req)
	if err != nil {
		toFail(t, "handler error: %v", err)
	}

	msg := requireErrorText(t, res)
	if !strings.Contains(msg, "outside the authorized organization scope") {
		toFail(t, "expected organization scope mismatch message, got %q", msg)
	}
	if len(rbac.lastRequests) != 0 {
		toFail(t, "expected no RBAC calls, got %d", len(rbac.lastRequests))
	}
	if loghubClient.lastRequest != nil {
		toFail(t, "expected no loghub call, got %+v", loghubClient.lastRequest)
	}
}

func TestLogsRBACUnavailable(t *testing.T) {
	jobID := "99999999-aaaa-bbbb-cccc-dddddddddddd"
	orgID := "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
	jobClient := &jobClientStub{
		describeResp: &jobpb.DescribeResponse{
			Status: &responsepb.ResponseStatus{Code: responsepb.ResponseStatus_OK},
			Job: &jobpb.Job{
				Id:             jobID,
				ProjectId:      "proj-1",
				OrganizationId: orgID,
				SelfHosted:     false,
			},
		},
	}
	loghubClient := &loghubClientStub{}

	provider := &support.MockProvider{
		JobClient:    jobClient,
		LoghubClient: loghubClient,
		Timeout:      time.Second,
	}

	req := mcp.CallToolRequest{Params: mcp.CallToolParams{Arguments: map[string]any{
		"organization_id": orgID,
		"job_id":          jobID,
	}}}
	header := http.Header{}
	header.Set("X-Semaphore-User-ID", "99999999-aaaa-bbbb-cccc-dddddddddddd")
	req.Header = header

	res, err := logsHandler(provider)(context.Background(), req)
	if err != nil {
		toFail(t, "handler error: %v", err)
	}

	msg := requireErrorText(t, res)
	if !strings.Contains(msg, "Authorization service is not configured") {
		toFail(t, "expected RBAC unavailable message, got %q", msg)
	}
	if loghubClient.lastRequest != nil {
		toFail(t, "expected no loghub call, got %+v", loghubClient.lastRequest)
	}
}

type jobClientStub struct {
	jobpb.JobServiceClient
	describeResp *jobpb.DescribeResponse
	describeErr  error
	lastDescribe *jobpb.DescribeRequest
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

func requireErrorText(t *testing.T, res *mcp.CallToolResult) string {
	t.Helper()
	if res == nil {
		t.Fatalf("expected tool result")
	}
	if !res.IsError {
		t.Fatalf("expected error result, got success")
	}
	if len(res.Content) == 0 {
		t.Fatalf("expected error content")
	}
	text, ok := res.Content[0].(mcp.TextContent)
	if !ok {
		t.Fatalf("expected text content, got %T", res.Content[0])
	}
	return text.Text
}

func newRBACStub(perms ...string) *rbacStub {
	copied := append([]string(nil), perms...)
	return &rbacStub{permissions: copied}
}

type rbacStub struct {
	rbacpb.RBACClient

	permissions     []string
	perProject      map[string][]string
	perOrg          map[string][]string
	err             error
	errorForProject map[string]error
	errorForOrg     map[string]error
	lastRequests    []*rbacpb.ListUserPermissionsRequest
}

func (s *rbacStub) ListUserPermissions(ctx context.Context, in *rbacpb.ListUserPermissionsRequest, opts ...grpc.CallOption) (*rbacpb.ListUserPermissionsResponse, error) {
	reqCopy := &rbacpb.ListUserPermissionsRequest{
		UserId:    in.GetUserId(),
		OrgId:     in.GetOrgId(),
		ProjectId: in.GetProjectId(),
	}
	s.lastRequests = append(s.lastRequests, reqCopy)

	if s.err != nil {
		return nil, s.err
	}

	projectKey := normalizeKey(in.GetProjectId())
	orgKey := normalizeKey(in.GetOrgId())

	if projectKey != "" {
		if err := s.errorForProject[projectKey]; err != nil {
			return nil, err
		}
	} else if orgKey != "" {
		if err := s.errorForOrg[orgKey]; err != nil {
			return nil, err
		}
	}

	perms := s.permissions
	if projectKey != "" {
		if override, ok := s.perProject[projectKey]; ok {
			perms = override
		}
	} else if orgKey != "" {
		if override, ok := s.perOrg[orgKey]; ok {
			perms = override
		}
	}
	if perms == nil {
		perms = []string{}
	}

	return &rbacpb.ListUserPermissionsResponse{
		UserId:      in.GetUserId(),
		OrgId:       in.GetOrgId(),
		ProjectId:   in.GetProjectId(),
		Permissions: append([]string(nil), perms...),
	}, nil
}

func normalizeKey(value string) string {
	return strings.ToLower(strings.TrimSpace(value))
}

func toFail(t *testing.T, format string, args ...any) {
	t.Helper()
	t.Fatalf(format, args...)
}
