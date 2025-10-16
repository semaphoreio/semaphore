package internalapi

import (
	"time"

	loghubpb "github.com/semaphoreio/semaphore/mcp_server/pkg/internal_api/loghub"
	loghub2pb "github.com/semaphoreio/semaphore/mcp_server/pkg/internal_api/loghub2"
	pipelinepb "github.com/semaphoreio/semaphore/mcp_server/pkg/internal_api/plumber.pipeline"
	workflowpb "github.com/semaphoreio/semaphore/mcp_server/pkg/internal_api/plumber_w_f.workflow"
	jobpb "github.com/semaphoreio/semaphore/mcp_server/pkg/internal_api/server_farm.job"
)

// MockProvider is a lightweight Provider implementation intended for tests.
type MockProvider struct {
	WorkflowClient workflowpb.WorkflowServiceClient
	PipelineClient pipelinepb.PipelineServiceClient
	JobClient      jobpb.JobServiceClient
	LoghubClient   loghubpb.LoghubClient
	Loghub2Client  loghub2pb.Loghub2Client
	Timeout        time.Duration
}

func (m *MockProvider) CallTimeout() time.Duration {
	if m.Timeout == 0 {
		return time.Second
	}
	return m.Timeout
}

func (m *MockProvider) Workflow() workflowpb.WorkflowServiceClient { return m.WorkflowClient }

func (m *MockProvider) Pipelines() pipelinepb.PipelineServiceClient { return m.PipelineClient }

func (m *MockProvider) Jobs() jobpb.JobServiceClient { return m.JobClient }

func (m *MockProvider) Loghub() loghubpb.LoghubClient { return m.LoghubClient }

func (m *MockProvider) Loghub2() loghub2pb.Loghub2Client { return m.Loghub2Client }
