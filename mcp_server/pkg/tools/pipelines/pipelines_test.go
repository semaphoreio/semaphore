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
	client := &pipelineClientStub{
		listResp: &pipelinepb.ListKeysetResponse{
			Pipelines: []*pipelinepb.Pipeline{
				{
					PplId:         "ppl-1",
					Name:          "Build",
					WfId:          "wf-1",
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
		"workflow_id": "wf-1",
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
	if ppl.ID != "ppl-1" || ppl.Triggerer != "promotion" || ppl.Queue.ID != "queue-1" {
		toFail(t, "unexpected pipeline summary: %+v", ppl)
	}

	if result.NextCursor != "cursor" {
		toFail(t, "expected next cursor 'cursor', got %q", result.NextCursor)
	}

	if client.lastList == nil || client.lastList.GetWfId() != "wf-1" {
		toFail(t, "unexpected list request: %+v", client.lastList)
	}
}

func TestDescribePipeline(t *testing.T) {
	blocks := []*pipelinepb.Block{
		{
			BlockId:          "block-1",
			Name:             "Tests",
			BuildReqId:       "req-1",
			State:            pipelinepb.Block_RUNNING,
			Result:           pipelinepb.Block_PASSED,
			ResultReason:     pipelinepb.Block_TEST,
			ErrorDescription: "",
			Jobs: []*pipelinepb.Block_Job{
				{Name: "job-1", Index: 0, JobId: "job-1", Status: "RUNNING", Result: "PASSED"},
			},
		},
	}

	client := &pipelineClientStub{
		describeResp: &pipelinepb.DescribeResponse{
			ResponseStatus: &pipelinepb.ResponseStatus{Code: pipelinepb.ResponseStatus_OK},
			Pipeline: &pipelinepb.Pipeline{
				PplId:     "ppl-1",
				Name:      "Build",
				WfId:      "wf-1",
				ProjectId: "proj-1",
			},
			Blocks: blocks,
		},
	}

	provider := &internalapi.MockProvider{PipelineClient: client, Timeout: time.Second}
	handler := describeHandler(provider)
	req := mcp.CallToolRequest{Params: mcp.CallToolParams{Arguments: map[string]any{
		"pipeline_id": "ppl-1",
		"detailed":    true,
	}}}

	res, err := handler(context.Background(), req)
	if err != nil {
		toFail(t, "handler error: %v", err)
	}

	result, ok := res.StructuredContent.(describeResult)
	if !ok {
		toFail(t, "unexpected structured content type: %T", res.StructuredContent)
	}

	if result.Pipeline.ID != "ppl-1" {
		toFail(t, "unexpected pipeline id: %s", result.Pipeline.ID)
	}
	if len(result.Blocks) != 1 || len(result.Blocks[0].Jobs) != 1 {
		toFail(t, "unexpected block summary: %+v", result.Blocks)
	}

	if client.lastDescribe == nil || !client.lastDescribe.GetDetailed() {
		toFail(t, "expected describe request to set detailed flag")
	}
}

type pipelineClientStub struct {
	pipelinepb.PipelineServiceClient
	listResp     *pipelinepb.ListKeysetResponse
	listErr      error
	describeResp *pipelinepb.DescribeResponse
	describeErr  error
	lastList     *pipelinepb.ListKeysetRequest
	lastDescribe *pipelinepb.DescribeRequest
}

func (s *pipelineClientStub) Schedule(context.Context, *pipelinepb.ScheduleRequest, ...grpc.CallOption) (*pipelinepb.ScheduleResponse, error) {
	panic("not implemented")
}

func (s *pipelineClientStub) Describe(ctx context.Context, in *pipelinepb.DescribeRequest, opts ...grpc.CallOption) (*pipelinepb.DescribeResponse, error) {
	s.lastDescribe = in
	if s.describeErr != nil {
		return nil, s.describeErr
	}
	return s.describeResp, nil
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
