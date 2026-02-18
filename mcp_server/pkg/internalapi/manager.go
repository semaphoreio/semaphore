package internalapi

import (
	"context"
	"errors"
	"fmt"
	"strings"
	"time"

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
	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials/insecure"
)

// Provider exposes access to internal API clients.
type Provider interface {
	CallTimeout() time.Duration
	BaseURL() string
	Workflow() workflowpb.WorkflowServiceClient
	Organizations() orgpb.OrganizationServiceClient
	Projects() projecthubpb.ProjectServiceClient
	Pipelines() pipelinepb.PipelineServiceClient
	Jobs() jobpb.JobServiceClient
	Artifacthub() artifacthubpb.ArtifactServiceClient
	Loghub() loghubpb.LoghubClient
	Loghub2() loghub2pb.Loghub2Client
	Users() userpb.UserServiceClient
	RBAC() rbacpb.RBACClient
	Features() featuresvc.FeatureClient
}

// Manager owns gRPC connections to internal API services and exposes typed clients.
type Manager struct {
	cfg Config

	workflowConn     *grpc.ClientConn
	organizationConn *grpc.ClientConn
	projectConn      *grpc.ClientConn
	pipelineConn     *grpc.ClientConn
	jobConn          *grpc.ClientConn
	artifacthubConn  *grpc.ClientConn
	loghubConn       *grpc.ClientConn
	loghub2Conn      *grpc.ClientConn
	userConn         *grpc.ClientConn
	rbacConn         *grpc.ClientConn

	workflowClient     workflowpb.WorkflowServiceClient
	organizationClient orgpb.OrganizationServiceClient
	projectClient      projecthubpb.ProjectServiceClient
	pipelineClient     pipelinepb.PipelineServiceClient
	jobClient          jobpb.JobServiceClient
	artifacthubClient  artifacthubpb.ArtifactServiceClient
	loghubClient       loghubpb.LoghubClient
	loghub2Client      loghub2pb.Loghub2Client
	userClient         userpb.UserServiceClient
	rbacClient         rbacpb.RBACClient
	featuresService    featuresvc.FeatureClient
}

// NewManager dials the configured services and returns a ready-to-use manager.
func NewManager(ctx context.Context, cfg Config) (*Manager, error) {
	m := &Manager{cfg: cfg}

	dial := func(target string) (*grpc.ClientConn, error) {
		if target == "" {
			return nil, nil
		}

		dialCtx, cancel := context.WithTimeout(ctx, cfg.DialTimeout)
		defer cancel()

		conn, err := grpc.DialContext(
			dialCtx,
			target,
			grpc.WithTransportCredentials(insecure.NewCredentials()),
			grpc.WithDefaultCallOptions(grpc.WaitForReady(true)),
			grpc.WithBlock(),
		)
		if err != nil {
			return nil, err
		}
		return conn, nil
	}

	var err error
	handleDialError := func(service string, dialErr error) error {
		if dialErr == nil {
			return nil
		}
		if closeErr := m.Close(); closeErr != nil {
			return fmt.Errorf("connect %s service: %w (cleanup failed: %v)", service, dialErr, closeErr)
		}
		return fmt.Errorf("connect %s service: %w", service, dialErr)
	}
	if m.workflowConn, err = dial(cfg.WorkflowEndpoint); err != nil {
		return nil, fmt.Errorf("connect workflow service: %w", err)
	}
	if m.organizationConn, err = dial(cfg.OrganizationEndpoint); err != nil {
		return nil, handleDialError("organization", err)
	}
	if m.projectConn, err = dial(cfg.ProjectEndpoint); err != nil {
		return nil, handleDialError("project", err)
	}
	if m.pipelineConn, err = dial(cfg.PipelineEndpoint); err != nil {
		return nil, handleDialError("pipeline", err)
	}
	if m.jobConn, err = dial(cfg.JobEndpoint); err != nil {
		return nil, handleDialError("job", err)
	}
	if m.artifacthubConn, err = dial(cfg.ArtifacthubEndpoint); err != nil {
		return nil, handleDialError("artifacthub", err)
	}
	if m.loghubConn, err = dial(cfg.LoghubEndpoint); err != nil {
		return nil, handleDialError("loghub", err)
	}
	if m.loghub2Conn, err = dial(cfg.Loghub2Endpoint); err != nil {
		return nil, handleDialError("loghub2", err)
	}
	if m.userConn, err = dial(cfg.UserEndpoint); err != nil {
		return nil, handleDialError("user", err)
	}
	if m.rbacConn, err = dial(cfg.RBACEndpoint); err != nil {
		return nil, handleDialError("rbac", err)
	}

	if m.workflowConn != nil {
		m.workflowClient = workflowpb.NewWorkflowServiceClient(m.workflowConn)
	}
	if m.organizationConn != nil {
		m.organizationClient = orgpb.NewOrganizationServiceClient(m.organizationConn)
	}
	if m.projectConn != nil {
		m.projectClient = projecthubpb.NewProjectServiceClient(m.projectConn)
	}
	if m.pipelineConn != nil {
		m.pipelineClient = pipelinepb.NewPipelineServiceClient(m.pipelineConn)
	}
	if m.jobConn != nil {
		m.jobClient = jobpb.NewJobServiceClient(m.jobConn)
	}
	if m.artifacthubConn != nil {
		m.artifacthubClient = artifacthubpb.NewArtifactServiceClient(m.artifacthubConn)
	}
	if m.loghubConn != nil {
		m.loghubClient = loghubpb.NewLoghubClient(m.loghubConn)
	}
	if m.loghub2Conn != nil {
		m.loghub2Client = loghub2pb.NewLoghub2Client(m.loghub2Conn)
	}
	if m.userConn != nil {
		m.userClient = userpb.NewUserServiceClient(m.userConn)
	}
	if m.rbacConn != nil {
		m.rbacClient = rbacpb.NewRBACClient(m.rbacConn)
	}

	cacheService := featuresvc.NewCacheService()

	m.featuresService = featuresvc.NewFeatureService(cfg.FeatureHubEndpoint, cacheService, cfg.CallTimeout)

	return m, nil
}

// Close tears down all gRPC connections owned by the manager.
func (m *Manager) Close() error {
	var errs []error
	closers := []*grpc.ClientConn{
		m.workflowConn,
		m.organizationConn,
		m.projectConn,
		m.pipelineConn,
		m.jobConn,
		m.artifacthubConn,
		m.loghubConn,
		m.loghub2Conn,
		m.userConn,
		m.rbacConn,
	}
	for _, conn := range closers {
		if conn == nil {
			continue
		}
		if err := conn.Close(); err != nil {
			errs = append(errs, err)
		}
	}

	if len(errs) == 0 {
		return nil
	}
	return joinErrors(errs)
}

// CallTimeout returns the timeout applied to outbound RPCs.
func (m *Manager) CallTimeout() time.Duration {
	return m.cfg.CallTimeout
}

// BaseURL returns the base URL for the Semaphore installation.
func (m *Manager) BaseURL() string {
	return m.cfg.BaseURL
}

func (m *Manager) Workflow() workflowpb.WorkflowServiceClient {
	return m.workflowClient
}

func (m *Manager) Organizations() orgpb.OrganizationServiceClient {
	return m.organizationClient
}

func (m *Manager) Projects() projecthubpb.ProjectServiceClient {
	return m.projectClient
}

func (m *Manager) Pipelines() pipelinepb.PipelineServiceClient {
	return m.pipelineClient
}

func (m *Manager) Jobs() jobpb.JobServiceClient {
	return m.jobClient
}

func (m *Manager) Artifacthub() artifacthubpb.ArtifactServiceClient {
	return m.artifacthubClient
}

func (m *Manager) Loghub() loghubpb.LoghubClient {
	return m.loghubClient
}

func (m *Manager) Loghub2() loghub2pb.Loghub2Client {
	return m.loghub2Client
}

func (m *Manager) Users() userpb.UserServiceClient {
	return m.userClient
}

func (m *Manager) RBAC() rbacpb.RBACClient {
	return m.rbacClient
}

func (m *Manager) Features() featuresvc.FeatureClient {
	return m.featuresService
}

func joinErrors(errs []error) error {
	if len(errs) == 1 {
		return errs[0]
	}

	msgs := make([]string, 0, len(errs))
	for _, err := range errs {
		msgs = append(msgs, err.Error())
	}
	return errors.New(strings.Join(msgs, "; "))
}
