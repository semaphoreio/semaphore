package stubs

import (
	"context"
	"time"

	loghubpb "github.com/semaphoreio/semaphore/mcp_server/pkg/internal_api/loghub"
	loghub2pb "github.com/semaphoreio/semaphore/mcp_server/pkg/internal_api/loghub2"
	pipelinepb "github.com/semaphoreio/semaphore/mcp_server/pkg/internal_api/plumber.pipeline"
	workflowpb "github.com/semaphoreio/semaphore/mcp_server/pkg/internal_api/plumber_w_f.workflow"
	responsepb "github.com/semaphoreio/semaphore/mcp_server/pkg/internal_api/response_status"
	jobpb "github.com/semaphoreio/semaphore/mcp_server/pkg/internal_api/server_farm.job"
	statuspb "github.com/semaphoreio/semaphore/mcp_server/pkg/internal_api/status"
	"github.com/semaphoreio/semaphore/mcp_server/pkg/internalapi"

	code "google.golang.org/genproto/googleapis/rpc/code"
	"google.golang.org/grpc"
	"google.golang.org/protobuf/types/known/timestamppb"
)

// New returns an internalapi.Provider backed by deterministic stub responses useful for local development.
func New() internalapi.Provider {
	return &provider{
		timeout:   time.Second,
		workflows: &workflowStub{},
		pipelines: &pipelineStub{},
		jobs:      &jobStub{},
		loghub:    &loghubStub{},
		loghub2:   &loghub2Stub{},
	}
}

type provider struct {
	timeout   time.Duration
	workflows workflowpb.WorkflowServiceClient
	pipelines pipelinepb.PipelineServiceClient
	jobs      jobpb.JobServiceClient
	loghub    loghubpb.LoghubClient
	loghub2   loghub2pb.Loghub2Client
}

func (p *provider) CallTimeout() time.Duration { return p.timeout }

func (p *provider) Workflow() workflowpb.WorkflowServiceClient { return p.workflows }

func (p *provider) Pipelines() pipelinepb.PipelineServiceClient { return p.pipelines }

func (p *provider) Jobs() jobpb.JobServiceClient { return p.jobs }

func (p *provider) Loghub() loghubpb.LoghubClient { return p.loghub }

func (p *provider) Loghub2() loghub2pb.Loghub2Client { return p.loghub2 }

// --- workflow stub ---

type workflowStub struct {
	workflowpb.WorkflowServiceClient
}

func (w *workflowStub) ListKeyset(ctx context.Context, in *workflowpb.ListKeysetRequest, opts ...grpc.CallOption) (*workflowpb.ListKeysetResponse, error) {
	return &workflowpb.ListKeysetResponse{
		Status: &statuspb.Status{Code: code.Code_OK},
		Workflows: []*workflowpb.WorkflowDetails{
			{
				WfId:           "wf-local",
				InitialPplId:   "ppl-local",
				ProjectId:      orDefault(in.GetProjectId(), "project-local"),
				BranchName:     "main",
				CommitSha:      "abcdef0",
				CreatedAt:      timestamppb.New(time.Unix(1_700_000_000, 0)),
				TriggeredBy:    workflowpb.TriggeredBy_MANUAL_RUN,
				OrganizationId: "org-local",
			},
		},
		NextPageToken: "",
	}, nil
}

// --- pipeline stub ---

type pipelineStub struct {
	pipelinepb.PipelineServiceClient
}

func (p *pipelineStub) ListKeyset(ctx context.Context, in *pipelinepb.ListKeysetRequest, opts ...grpc.CallOption) (*pipelinepb.ListKeysetResponse, error) {
	return &pipelinepb.ListKeysetResponse{
		Pipelines: []*pipelinepb.Pipeline{
			{
				PplId:        "ppl-local",
				Name:         "Build",
				WfId:         orDefault(in.GetWfId(), "wf-local"),
				ProjectId:    orDefault(in.GetProjectId(), "project-local"),
				BranchName:   "main",
				CommitSha:    "abcdef0",
				State:        pipelinepb.Pipeline_RUNNING,
				Result:       pipelinepb.Pipeline_PASSED,
				ResultReason: pipelinepb.Pipeline_TEST,
				CreatedAt:    timestamppb.New(time.Unix(1_700_000_000, 0)),
				Queue:        &pipelinepb.Queue{QueueId: "queue-local", Name: "default", Type: pipelinepb.QueueType_IMPLICIT},
				Triggerer:    &pipelinepb.Triggerer{PplTriggeredBy: pipelinepb.TriggeredBy_WORKFLOW},
			},
		},
	}, nil
}

func (p *pipelineStub) Describe(ctx context.Context, in *pipelinepb.DescribeRequest, opts ...grpc.CallOption) (*pipelinepb.DescribeResponse, error) {
	return &pipelinepb.DescribeResponse{
		ResponseStatus: &pipelinepb.ResponseStatus{Code: pipelinepb.ResponseStatus_OK},
		Pipeline: &pipelinepb.Pipeline{
			PplId:     orDefault(in.GetPplId(), "ppl-local"),
			Name:      "Build",
			ProjectId: "project-local",
			WfId:      "wf-local",
		},
		Blocks: []*pipelinepb.Block{
			{
				BlockId:      "block-local",
				Name:         "Tests",
				State:        pipelinepb.Block_RUNNING,
				Result:       pipelinepb.Block_PASSED,
				ResultReason: pipelinepb.Block_TEST,
				Jobs: []*pipelinepb.Block_Job{{
					Name:  "job-local",
					JobId: "job-local",
				}},
			},
		},
	}, nil
}

// --- job stub ---

type jobStub struct {
	jobpb.JobServiceClient
}

func (j *jobStub) Describe(ctx context.Context, in *jobpb.DescribeRequest, opts ...grpc.CallOption) (*jobpb.DescribeResponse, error) {
	return &jobpb.DescribeResponse{
		Status: &responsepb.ResponseStatus{Code: responsepb.ResponseStatus_OK},
		Job: &jobpb.Job{
			Id:             orDefault(in.GetJobId(), "job-local"),
			Name:           "Test job",
			PplId:          "ppl-local",
			ProjectId:      "project-local",
			OrganizationId: "org-local",
			Timeline: &jobpb.Job_Timeline{
				CreatedAt: timestamppb.New(time.Unix(1_700_000_000, 0)),
			},
		},
	}, nil
}

// --- loghub stub ---

type loghubStub struct {
	loghubpb.LoghubClient
}

func (l *loghubStub) GetLogEvents(ctx context.Context, in *loghubpb.GetLogEventsRequest, opts ...grpc.CallOption) (*loghubpb.GetLogEventsResponse, error) {
	return &loghubpb.GetLogEventsResponse{
		Status: &responsepb.ResponseStatus{Code: responsepb.ResponseStatus_OK},
		Events: []string{"starting job", "running tests", "done"},
		Final:  true,
	}, nil
}

// --- loghub2 stub ---

type loghub2Stub struct {
	loghub2pb.Loghub2Client
}

func (l *loghub2Stub) GenerateToken(ctx context.Context, in *loghub2pb.GenerateTokenRequest, opts ...grpc.CallOption) (*loghub2pb.GenerateTokenResponse, error) {
	return &loghub2pb.GenerateTokenResponse{Token: "stub-token", Type: loghub2pb.TokenType_PULL}, nil
}

func orDefault(value, fallback string) string {
	if value != "" {
		return value
	}
	return fallback
}
