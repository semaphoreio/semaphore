package pipelines

import (
	"context"
	"testing"
	"time"

	"github.com/mark3labs/mcp-go/mcp"

	pipelinepb "github.com/semaphoreio/semaphore/mcp_server/pkg/internal_api/plumber.pipeline"
	"github.com/semaphoreio/semaphore/mcp_server/pkg/internalapi"

	"google.golang.org/grpc"
	"google.golang.org/protobuf/types/known/timestamppb"
)

func TestListPipelines(t *testing.T) {
	workflowID := "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
	pipelineID := "11111111-2222-3333-4444-555555555555"
	client := &pipelineClientStub{
		listResp: &pipelinepb.ListKeysetResponse{
			Pipelines: []*pipelinepb.Pipeline{
				{
					PplId:         pipelineID,
					Name:          "Build",
					WfId:          workflowID,
					ProjectId:     "proj-1",
					BranchName:    "main",
					CommitSha:     "abc123",
					State:         pipelinepb.Pipeline_RUNNING,
					Result:        pipelinepb.Pipeline_PASSED,
					ResultReason:  pipelinepb.Pipeline_TEST,
					CreatedAt:     timestamppb.New(time.Unix(1700000000, 0)),
					Queue:         &pipelinepb.Queue{QueueId: "queue-1", Name: "default", Type: pipelinepb.QueueType_IMPLICIT},
					Triggerer:     &pipelinepb.Triggerer{PplTriggeredBy: pipelinepb.TriggeredBy_PROMOTION},
					WithAfterTask: true,
					AfterTaskId:   "after-1",
				},
			},
			NextPageToken: "cursor",
		},
	}

	provider := &internalapi.MockProvider{PipelineClient: client, Timeout: time.Second}
	handler := listHandler(provider)
	req := mcp.CallToolRequest{Params: mcp.CallToolParams{Arguments: map[string]any{
		"workflow_id":     workflowID,
		"organization_id": "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
	}}}

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

func TestListPipelineJobs(t *testing.T) {
	pipelineID := "11111111-2222-3333-4444-555555555555"
	client := &pipelineClientStub{
		describeResp: &pipelinepb.DescribeResponse{
			Pipeline: &pipelinepb.Pipeline{
				PplId:     pipelineID,
				Name:      "Build",
				WfId:      "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
				ProjectId: "proj-1",
				State:     pipelinepb.Pipeline_RUNNING,
				Result:    pipelinepb.Pipeline_PASSED,
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

	provider := &internalapi.MockProvider{PipelineClient: client, Timeout: time.Second}
	handler := jobsHandler(provider)
	req := mcp.CallToolRequest{Params: mcp.CallToolParams{Arguments: map[string]any{
		"pipeline_id":     pipelineID,
		"organization_id": "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
	}}}

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

func toFail(t *testing.T, format string, args ...any) {
	t.Helper()
	t.Fatalf(format, args...)
}
