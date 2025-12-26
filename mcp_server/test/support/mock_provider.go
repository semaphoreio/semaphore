package support

import (
	"time"

	"github.com/semaphoreio/semaphore/mcp_server/pkg/feature"
	artifacthubpb "github.com/semaphoreio/semaphore/mcp_server/pkg/internal_api/artifacthub"
	loghubpb "github.com/semaphoreio/semaphore/mcp_server/pkg/internal_api/loghub"
	loghub2pb "github.com/semaphoreio/semaphore/mcp_server/pkg/internal_api/loghub2"
	orgpb "github.com/semaphoreio/semaphore/mcp_server/pkg/internal_api/organization"
	pipelinepb "github.com/semaphoreio/semaphore/mcp_server/pkg/internal_api/plumber.pipeline"
	workflowpb "github.com/semaphoreio/semaphore/mcp_server/pkg/internal_api/plumber_w_f.workflow"
	projecthubpb "github.com/semaphoreio/semaphore/mcp_server/pkg/internal_api/projecthub"
	rbacpb "github.com/semaphoreio/semaphore/mcp_server/pkg/internal_api/rbac"
	jobpb "github.com/semaphoreio/semaphore/mcp_server/pkg/internal_api/server_farm.job"
	userpb "github.com/semaphoreio/semaphore/mcp_server/pkg/internal_api/user"
	featuresvc "github.com/semaphoreio/semaphore/mcp_server/pkg/service"
)

// MockProvider is a lightweight Provider implementation intended for tests.
type MockProvider struct {
	WorkflowClient     workflowpb.WorkflowServiceClient
	OrganizationClient orgpb.OrganizationServiceClient
	ProjectClient      projecthubpb.ProjectServiceClient
	PipelineClient     pipelinepb.PipelineServiceClient
	JobClient          jobpb.JobServiceClient
	ArtifacthubClient  artifacthubpb.ArtifactServiceClient
	LoghubClient       loghubpb.LoghubClient
	Loghub2Client      loghub2pb.Loghub2Client
	UserClient         userpb.UserServiceClient
	RBACClient         rbacpb.RBACClient
	FeaturesService    featuresvc.FeatureClient
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

func (m *MockProvider) Artifacthub() artifacthubpb.ArtifactServiceClient {
	return m.ArtifacthubClient
}

func (m *MockProvider) Loghub() loghubpb.LoghubClient { return m.LoghubClient }

func (m *MockProvider) Loghub2() loghub2pb.Loghub2Client { return m.Loghub2Client }

func (m *MockProvider) Users() userpb.UserServiceClient { return m.UserClient }

func (m *MockProvider) RBAC() rbacpb.RBACClient { return m.RBACClient }

func (m *MockProvider) Features() featuresvc.FeatureClient {
	if m.FeaturesService == nil {
		return alwaysEnabledFeatureClient{}
	}
	return m.FeaturesService
}

type alwaysEnabledFeatureClient struct{}

func (alwaysEnabledFeatureClient) ListOrganizationFeatures(string) ([]feature.OrganizationFeature, error) {
	return []feature.OrganizationFeature{
		{Name: "mcp_server_read_tools", State: feature.Enabled, Quantity: 1},
	}, nil
}

func (alwaysEnabledFeatureClient) FeatureState(string, string) (feature.State, error) {
	return feature.Enabled, nil
}
