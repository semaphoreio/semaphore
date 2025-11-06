package pipelines

import (
	"context"
	"errors"
	"net/http"
	"strings"
	"testing"
	"time"

	"github.com/mark3labs/mcp-go/mcp"
	"github.com/semaphoreio/semaphore/mcp_server/pkg/feature"
	pipelinepb "github.com/semaphoreio/semaphore/mcp_server/pkg/internal_api/plumber.pipeline"
	rbacpb "github.com/semaphoreio/semaphore/mcp_server/pkg/internal_api/rbac"
	support "github.com/semaphoreio/semaphore/mcp_server/test/support"

	"google.golang.org/grpc"
	"google.golang.org/protobuf/types/known/timestamppb"
)

func TestListPipelines_FeatureFlagDisabled(t *testing.T) {
	req := mcp.CallToolRequest{Params: mcp.CallToolParams{Arguments: map[string]any{
		"organization_id": "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
		"workflow_id":     "11111111-2222-3333-4444-555555555555",
	}}}
	header := http.Header{}
	header.Set("X-Semaphore-User-ID", "99999999-aaaa-bbbb-cccc-dddddddddddd")
	req.Header = header

	provider := &support.MockProvider{
		FeaturesService: support.FeatureClientStub{State: feature.Hidden},
		Timeout:         time.Second,
		PipelineClient:  &pipelineClientStub{},
		RBACClient:      newRBACStub("project.view"),
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

func TestPipelineJobs_FeatureFlagDisabled(t *testing.T) {
	req := mcp.CallToolRequest{Params: mcp.CallToolParams{Arguments: map[string]any{
		"organization_id": "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
		"pipeline_id":     "11111111-2222-3333-4444-555555555555",
	}}}
	header := http.Header{}
	header.Set("X-Semaphore-User-ID", "99999999-aaaa-bbbb-cccc-dddddddddddd")
	req.Header = header

	provider := &support.MockProvider{
		FeaturesService: support.FeatureClientStub{State: feature.Hidden},
		Timeout:         time.Second,
		PipelineClient:  &pipelineClientStub{},
		RBACClient:      newRBACStub("project.view"),
	}

	res, err := jobsHandler(provider)(context.Background(), req)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	msg := requireErrorText(t, res)
	if !strings.Contains(strings.ToLower(msg), "disabled") {
		t.Fatalf("expected disabled feature error, got %q", msg)
	}
}

func TestListPipelines(t *testing.T) {
	workflowID := "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
	pipelineID := "11111111-2222-3333-4444-555555555555"
	client := &pipelineClientStub{
		listResp: &pipelinepb.ListKeysetResponse{
			Pipelines: []*pipelinepb.Pipeline{
				{
					PplId:          pipelineID,
					Name:           "Build",
					WfId:           workflowID,
					ProjectId:      "proj-1",
					OrganizationId: "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
					BranchName:     "main",
					CommitSha:      "abc123",
					State:          pipelinepb.Pipeline_RUNNING,
					Result:         pipelinepb.Pipeline_PASSED,
					ResultReason:   pipelinepb.Pipeline_TEST,
					CreatedAt:      timestamppb.New(time.Unix(1700000000, 0)),
					Queue:          &pipelinepb.Queue{QueueId: "queue-1", Name: "default", Type: pipelinepb.QueueType_IMPLICIT},
					Triggerer:      &pipelinepb.Triggerer{PplTriggeredBy: pipelinepb.TriggeredBy_PROMOTION},
					WithAfterTask:  true,
					AfterTaskId:    "after-1",
				},
			},
			NextPageToken: "cursor",
		},
	}

	provider := &support.MockProvider{PipelineClient: client, Timeout: time.Second, RBACClient: newRBACStub("project.view")}
	handler := listHandler(provider)
	req := mcp.CallToolRequest{Params: mcp.CallToolParams{Arguments: map[string]any{
		"workflow_id":     workflowID,
		"organization_id": "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
	}}}
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

	if len(result.Pipelines) != 1 {
		toFail(t, "expected 1 pipeline, got %d", len(result.Pipelines))
	}

	ppl := result.Pipelines[0]
	if ppl.ID != pipelineID || ppl.Triggerer != "promotion" || ppl.Queue.ID != "queue-1" {
		toFail(t, "unexpected pipeline summary: %+v", ppl)
	}

	if result.NextCursor != "cursor" {
		toFail(t, "expected next cursor 'cursor', got %q", result.NextCursor)
	}

	if client.lastList == nil || client.lastList.GetWfId() != workflowID {
		toFail(t, "unexpected list request: %+v", client.lastList)
	}
}

func TestListPipelinesPermissionDeniedWithProjectFilter(t *testing.T) {
	workflowID := "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
	projectID := "11111111-2222-3333-4444-555555555555"
	pipelineClient := &pipelineClientStub{}
	rbac := newRBACStub("organization.view")

	provider := &support.MockProvider{
		PipelineClient: pipelineClient,
		RBACClient:     rbac,
		Timeout:        time.Second,
	}

	req := mcp.CallToolRequest{Params: mcp.CallToolParams{Arguments: map[string]any{
		"workflow_id":     workflowID,
		"organization_id": "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
		"project_id":      projectID,
	}}}
	header := http.Header{}
	header.Set("X-Semaphore-User-ID", "99999999-aaaa-bbbb-cccc-dddddddddddd")
	req.Header = header

	res, err := listHandler(provider)(context.Background(), req)
	if err != nil {
		toFail(t, "handler error: %v", err)
	}

	msg := requireErrorText(t, res)
	if !strings.Contains(msg, `Permission denied while accessing project `+projectID) {
		toFail(t, "expected project denial message, got %q", msg)
	}
	if pipelineClient.lastList != nil {
		toFail(t, "expected no pipeline ListKeyset call, got %+v", pipelineClient.lastList)
	}
	if len(rbac.lastRequests) != 1 {
		toFail(t, "expected one RBAC request, got %d", len(rbac.lastRequests))
	}
	if got := rbac.lastRequests[0].GetProjectId(); got != projectID {
		toFail(t, "expected RBAC project %s, got %s", projectID, got)
	}
}

func TestListPipelinesSkipsUnauthorizedProjects(t *testing.T) {
	workflowID := "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
	client := &pipelineClientStub{
		listResp: &pipelinepb.ListKeysetResponse{
			Pipelines: []*pipelinepb.Pipeline{
				{
					PplId:          "ppl-denied",
					Name:           "Denied Pipeline",
					WfId:           workflowID,
					ProjectId:      "proj-denied",
					OrganizationId: "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
				},
				{
					PplId:          "ppl-allowed",
					Name:           "Allowed Pipeline",
					WfId:           workflowID,
					ProjectId:      "proj-allowed",
					OrganizationId: "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
				},
			},
		},
	}
	rbac := newRBACStub()
	rbac.perProject = map[string][]string{
		"proj-denied":  {},
		"proj-allowed": {"project.view"},
	}

	provider := &support.MockProvider{
		PipelineClient: client,
		RBACClient:     rbac,
		Timeout:        time.Second,
	}

	req := mcp.CallToolRequest{Params: mcp.CallToolParams{Arguments: map[string]any{
		"workflow_id":     workflowID,
		"organization_id": "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
	}}}
	header := http.Header{}
	header.Set("X-Semaphore-User-ID", "99999999-aaaa-bbbb-cccc-dddddddddddd")
	req.Header = header

	res, err := listHandler(provider)(context.Background(), req)
	if err != nil {
		toFail(t, "handler error: %v", err)
	}
	if res.IsError {
		toFail(t, "unexpected error result: %+v", res)
	}

	out, ok := res.StructuredContent.(listResult)
	if !ok {
		toFail(t, "unexpected structured content type: %T", res.StructuredContent)
	}
	if len(out.Pipelines) != 1 {
		toFail(t, "expected 1 pipeline after filtering, got %d", len(out.Pipelines))
	}
	if out.Pipelines[0].ID != "ppl-allowed" {
		toFail(t, "expected allowed pipeline, got %+v", out.Pipelines[0])
	}
	if len(rbac.lastRequests) != 2 {
		toFail(t, "expected RBAC to be called twice, got %d", len(rbac.lastRequests))
	}
}

func TestListPipelinesScopeMismatchOrganization(t *testing.T) {
	workflowID := "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
	client := &pipelineClientStub{
		listResp: &pipelinepb.ListKeysetResponse{
			Pipelines: []*pipelinepb.Pipeline{
				{
					PplId:          "ppl-1",
					Name:           "Build",
					WfId:           workflowID,
					ProjectId:      "proj-1",
					OrganizationId: "bbbbbbbb-cccc-dddd-eeee-ffffffffffff",
				},
			},
		},
	}
	rbac := newRBACStub("project.view")
	provider := &support.MockProvider{
		PipelineClient: client,
		RBACClient:     rbac,
		Timeout:        time.Second,
	}

	req := mcp.CallToolRequest{Params: mcp.CallToolParams{Arguments: map[string]any{
		"workflow_id":     workflowID,
		"organization_id": "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
	}}}
	header := http.Header{}
	header.Set("X-Semaphore-User-ID", "99999999-aaaa-bbbb-cccc-dddddddddddd")
	req.Header = header

	res, err := listHandler(provider)(context.Background(), req)
	if err != nil {
		toFail(t, "handler error: %v", err)
	}

	msg := requireErrorText(t, res)
	if !strings.Contains(msg, "outside the authorized organization scope") {
		toFail(t, "expected scope mismatch message, got %q", msg)
	}
	if len(rbac.lastRequests) != 0 {
		toFail(t, "expected no RBAC calls, got %d", len(rbac.lastRequests))
	}
}

func TestListPipelinesRBACError(t *testing.T) {
	workflowID := "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
	client := &pipelineClientStub{
		listResp: &pipelinepb.ListKeysetResponse{
			Pipelines: []*pipelinepb.Pipeline{
				{
					PplId:          "ppl-1",
					Name:           "Build",
					WfId:           workflowID,
					ProjectId:      "proj-1",
					OrganizationId: "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
				},
			},
		},
	}
	rbac := newRBACStub("project.view")
	rbac.errorForProject = map[string]error{
		"proj-1": errors.New("rbac rpc failure"),
	}

	provider := &support.MockProvider{
		PipelineClient: client,
		RBACClient:     rbac,
		Timeout:        time.Second,
	}

	req := mcp.CallToolRequest{Params: mcp.CallToolParams{Arguments: map[string]any{
		"workflow_id":     workflowID,
		"organization_id": "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
	}}}
	header := http.Header{}
	header.Set("X-Semaphore-User-ID", "99999999-aaaa-bbbb-cccc-dddddddddddd")
	req.Header = header

	res, err := listHandler(provider)(context.Background(), req)
	if err != nil {
		toFail(t, "handler error: %v", err)
	}

	msg := requireErrorText(t, res)
	if !strings.Contains(msg, "Authorization check failed") {
		toFail(t, "expected RBAC error message, got %q", msg)
	}
	if len(rbac.lastRequests) != 1 {
		toFail(t, "expected one RBAC call, got %d", len(rbac.lastRequests))
	}
}

func TestListPipelineJobs(t *testing.T) {
	pipelineID := "11111111-2222-3333-4444-555555555555"
	client := &pipelineClientStub{
		describeResp: &pipelinepb.DescribeResponse{
			Pipeline: &pipelinepb.Pipeline{
				PplId:          pipelineID,
				Name:           "Build",
				WfId:           "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
				ProjectId:      "proj-1",
				OrganizationId: "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
				State:          pipelinepb.Pipeline_RUNNING,
				Result:         pipelinepb.Pipeline_PASSED,
			},
			Blocks: []*pipelinepb.Block{
				{
					BlockId: "block-1",
					Name:    "Tests",
					State:   pipelinepb.Block_RUNNING,
					Result:  pipelinepb.Block_PASSED,
					Jobs: []*pipelinepb.Block_Job{
						{Name: "unit", JobId: "job-1", Index: 0, Status: "running", Result: "unknown"},
						{Name: "integration", JobId: "job-2", Index: 1, Status: "queued", Result: "unknown"},
					},
				},
			},
		},
	}

	provider := &support.MockProvider{PipelineClient: client, Timeout: time.Second, RBACClient: newRBACStub("project.view")}
	handler := jobsHandler(provider)
	req := mcp.CallToolRequest{Params: mcp.CallToolParams{Arguments: map[string]any{
		"pipeline_id":     pipelineID,
		"organization_id": "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
	}}}
	header := http.Header{}
	header.Set("X-Semaphore-User-ID", "99999999-aaaa-bbbb-cccc-dddddddddddd")
	req.Header = header

	res, err := handler(context.Background(), req)
	if err != nil {
		toFail(t, "handler error: %v", err)
	}

	result, ok := res.StructuredContent.(jobsListResult)
	if !ok {
		toFail(t, "unexpected structured content type: %T", res.StructuredContent)
	}
	if result.JobCount != 2 {
		toFail(t, "expected 2 jobs, got %d", result.JobCount)
	}
	if len(result.Blocks) != 1 || len(result.Blocks[0].Jobs) != 2 {
		toFail(t, "unexpected block grouping: %+v", result.Blocks)
	}
	if client.lastDescribe == nil || client.lastDescribe.GetPplId() != pipelineID {
		toFail(t, "expected describe request for pipeline, got %+v", client.lastDescribe)
	}
}

func TestPipelineJobsPermissionDenied(t *testing.T) {
	pipelineID := "11111111-2222-3333-4444-555555555555"
	client := &pipelineClientStub{
		describeResp: &pipelinepb.DescribeResponse{
			Pipeline: &pipelinepb.Pipeline{
				PplId:          pipelineID,
				Name:           "Build",
				WfId:           "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
				ProjectId:      "proj-1",
				OrganizationId: "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
				State:          pipelinepb.Pipeline_RUNNING,
				Result:         pipelinepb.Pipeline_PASSED,
			},
		},
	}
	rbac := newRBACStub()

	provider := &support.MockProvider{
		PipelineClient: client,
		RBACClient:     rbac,
		Timeout:        time.Second,
	}

	req := mcp.CallToolRequest{Params: mcp.CallToolParams{Arguments: map[string]any{
		"pipeline_id":     pipelineID,
		"organization_id": "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
	}}}
	header := http.Header{}
	header.Set("X-Semaphore-User-ID", "99999999-aaaa-bbbb-cccc-dddddddddddd")
	req.Header = header

	res, err := jobsHandler(provider)(context.Background(), req)
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
}

func TestPipelineJobsScopeMismatchOrganization(t *testing.T) {
	pipelineID := "11111111-2222-3333-4444-555555555555"
	client := &pipelineClientStub{
		describeResp: &pipelinepb.DescribeResponse{
			Pipeline: &pipelinepb.Pipeline{
				PplId:          pipelineID,
				Name:           "Build",
				WfId:           "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
				ProjectId:      "proj-1",
				OrganizationId: "bbbbbbbb-cccc-dddd-eeee-ffffffffffff",
				State:          pipelinepb.Pipeline_RUNNING,
				Result:         pipelinepb.Pipeline_PASSED,
			},
		},
	}
	rbac := newRBACStub("project.view")

	provider := &support.MockProvider{
		PipelineClient: client,
		RBACClient:     rbac,
		Timeout:        time.Second,
	}

	req := mcp.CallToolRequest{Params: mcp.CallToolParams{Arguments: map[string]any{
		"pipeline_id":     pipelineID,
		"organization_id": "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
	}}}
	header := http.Header{}
	header.Set("X-Semaphore-User-ID", "99999999-aaaa-bbbb-cccc-dddddddddddd")
	req.Header = header

	res, err := jobsHandler(provider)(context.Background(), req)
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

func TestPipelineJobsScopeMismatchProjectMissing(t *testing.T) {
	pipelineID := "11111111-2222-3333-4444-555555555555"
	client := &pipelineClientStub{
		describeResp: &pipelinepb.DescribeResponse{
			Pipeline: &pipelinepb.Pipeline{
				PplId:          pipelineID,
				Name:           "Build",
				WfId:           "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
				ProjectId:      "",
				OrganizationId: "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
				State:          pipelinepb.Pipeline_RUNNING,
				Result:         pipelinepb.Pipeline_PASSED,
			},
		},
	}
	rbac := newRBACStub("project.view")

	provider := &support.MockProvider{
		PipelineClient: client,
		RBACClient:     rbac,
		Timeout:        time.Second,
	}

	req := mcp.CallToolRequest{Params: mcp.CallToolParams{Arguments: map[string]any{
		"pipeline_id":     pipelineID,
		"organization_id": "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
	}}}
	header := http.Header{}
	header.Set("X-Semaphore-User-ID", "99999999-aaaa-bbbb-cccc-dddddddddddd")
	req.Header = header

	res, err := jobsHandler(provider)(context.Background(), req)
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

type pipelineClientStub struct {
	pipelinepb.PipelineServiceClient
	listResp     *pipelinepb.ListKeysetResponse
	listErr      error
	lastList     *pipelinepb.ListKeysetRequest
	describeResp *pipelinepb.DescribeResponse
	describeErr  error
	lastDescribe *pipelinepb.DescribeRequest
}

func (s *pipelineClientStub) Schedule(context.Context, *pipelinepb.ScheduleRequest, ...grpc.CallOption) (*pipelinepb.ScheduleResponse, error) {
	panic("not implemented")
}

func (s *pipelineClientStub) DescribeMany(context.Context, *pipelinepb.DescribeManyRequest, ...grpc.CallOption) (*pipelinepb.DescribeManyResponse, error) {
	panic("not implemented")
}

func (s *pipelineClientStub) DescribeTopology(context.Context, *pipelinepb.DescribeTopologyRequest, ...grpc.CallOption) (*pipelinepb.DescribeTopologyResponse, error) {
	panic("not implemented")
}

func (s *pipelineClientStub) Terminate(context.Context, *pipelinepb.TerminateRequest, ...grpc.CallOption) (*pipelinepb.TerminateResponse, error) {
	panic("not implemented")
}

func (s *pipelineClientStub) ListKeyset(ctx context.Context, in *pipelinepb.ListKeysetRequest, opts ...grpc.CallOption) (*pipelinepb.ListKeysetResponse, error) {
	s.lastList = in
	if s.listErr != nil {
		return nil, s.listErr
	}
	return s.listResp, nil
}

func (s *pipelineClientStub) Describe(ctx context.Context, in *pipelinepb.DescribeRequest, opts ...grpc.CallOption) (*pipelinepb.DescribeResponse, error) {
	s.lastDescribe = in
	if s.describeErr != nil {
		return nil, s.describeErr
	}
	if s.describeResp == nil {
		return &pipelinepb.DescribeResponse{}, nil
	}
	return s.describeResp, nil
}

func (s *pipelineClientStub) List(context.Context, *pipelinepb.ListRequest, ...grpc.CallOption) (*pipelinepb.ListResponse, error) {
	panic("not implemented")
}

func (s *pipelineClientStub) ListGrouped(context.Context, *pipelinepb.ListGroupedRequest, ...grpc.CallOption) (*pipelinepb.ListGroupedResponse, error) {
	panic("not implemented")
}

func (s *pipelineClientStub) ListQueues(context.Context, *pipelinepb.ListQueuesRequest, ...grpc.CallOption) (*pipelinepb.ListQueuesResponse, error) {
	panic("not implemented")
}

func (s *pipelineClientStub) ListActivity(context.Context, *pipelinepb.ListActivityRequest, ...grpc.CallOption) (*pipelinepb.ListActivityResponse, error) {
	panic("not implemented")
}

func (s *pipelineClientStub) ListRequesters(context.Context, *pipelinepb.ListRequestersRequest, ...grpc.CallOption) (*pipelinepb.ListRequestersResponse, error) {
	panic("not implemented")
}

func (s *pipelineClientStub) RunNow(context.Context, *pipelinepb.RunNowRequest, ...grpc.CallOption) (*pipelinepb.RunNowResponse, error) {
	panic("not implemented")
}

func (s *pipelineClientStub) GetProjectId(context.Context, *pipelinepb.GetProjectIdRequest, ...grpc.CallOption) (*pipelinepb.GetProjectIdResponse, error) {
	panic("not implemented")
}

func (s *pipelineClientStub) ValidateYaml(context.Context, *pipelinepb.ValidateYamlRequest, ...grpc.CallOption) (*pipelinepb.ValidateYamlResponse, error) {
	panic("not implemented")
}

func (s *pipelineClientStub) ScheduleExtension(context.Context, *pipelinepb.ScheduleExtensionRequest, ...grpc.CallOption) (*pipelinepb.ScheduleExtensionResponse, error) {
	panic("not implemented")
}

func (s *pipelineClientStub) Delete(context.Context, *pipelinepb.DeleteRequest, ...grpc.CallOption) (*pipelinepb.DeleteResponse, error) {
	panic("not implemented")
}

func (s *pipelineClientStub) PartialRebuild(context.Context, *pipelinepb.PartialRebuildRequest, ...grpc.CallOption) (*pipelinepb.PartialRebuildResponse, error) {
	panic("not implemented")
}

func (s *pipelineClientStub) Version(context.Context, *pipelinepb.VersionRequest, ...grpc.CallOption) (*pipelinepb.VersionResponse, error) {
	panic("not implemented")
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
