package internalapi

import (
	"time"

	rbacpb "github.com/semaphoreio/semaphore/mcp_server/pkg/internal_api/rbac"
	loghubpb "github.com/semaphoreio/semaphore/mcp_server/pkg/internal_api/loghub"
	loghub2pb "github.com/semaphoreio/semaphore/mcp_server/pkg/internal_api/loghub2"
	orgpb "github.com/semaphoreio/semaphore/mcp_server/pkg/internal_api/organization"
	pipelinepb "github.com/semaphoreio/semaphore/mcp_server/pkg/internal_api/plumber.pipeline"
	workflowpb "github.com/semaphoreio/semaphore/mcp_server/pkg/internal_api/plumber_w_f.workflow"
	projecthubpb "github.com/semaphoreio/semaphore/mcp_server/pkg/internal_api/projecthub"
	jobpb "github.com/semaphoreio/semaphore/mcp_server/pkg/internal_api/server_farm.job"
	userpb "github.com/semaphoreio/semaphore/mcp_server/pkg/internal_api/user"
)

// MockProvider is a lightweight Provider implementation intended for tests.
type MockProvider struct {
	WorkflowClient     workflowpb.WorkflowServiceClient
	OrganizationClient orgpb.OrganizationServiceClient
	ProjectClient      projecthubpb.ProjectServiceClient
	PipelineClient     pipelinepb.PipelineServiceClient
	JobClient          jobpb.JobServiceClient
	LoghubClient       loghubpb.LoghubClient
	Loghub2Client      loghub2pb.Loghub2Client
	UserClient         userpb.UserServiceClient
	RBACClient         rbacpb.RBACClient
	Timeout            time.Duration
}

func (m *MockProvider) CallTimeout() time.Duration {
	if m.Timeout == 0 {
		return time.Second
	}
	return m.Timeout
}

func (m *MockProvider) Workflow() workflowpb.WorkflowServiceClient { return m.WorkflowClient }

func (m *MockProvider) Organizations() orgpb.OrganizationServiceClient {
	return m.OrganizationClient
}

func (m *MockProvider) Projects() projecthubpb.ProjectServiceClient { return m.ProjectClient }

func (m *MockProvider) Pipelines() pipelinepb.PipelineServiceClient { return m.PipelineClient }

func (m *MockProvider) Jobs() jobpb.JobServiceClient { return m.JobClient }

func (m *MockProvider) Loghub() loghubpb.LoghubClient { return m.LoghubClient }

func (m *MockProvider) Loghub2() loghub2pb.Loghub2Client { return m.Loghub2Client }

func (m *MockProvider) Users() userpb.UserServiceClient { return m.UserClient }

func (m *MockProvider) RBAC() rbacpb.RBACClient { return m.RBACClient }
