package internalapi

import (
	"context"
	"errors"
	"fmt"
	"strings"
	"time"

	loghubpb "github.com/semaphoreio/semaphore/mcp_server/pkg/internal_api/loghub"
	loghub2pb "github.com/semaphoreio/semaphore/mcp_server/pkg/internal_api/loghub2"
	pipelinepb "github.com/semaphoreio/semaphore/mcp_server/pkg/internal_api/plumber.pipeline"
	workflowpb "github.com/semaphoreio/semaphore/mcp_server/pkg/internal_api/plumber_w_f.workflow"
	jobpb "github.com/semaphoreio/semaphore/mcp_server/pkg/internal_api/server_farm.job"
	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials/insecure"
)

// Provider exposes access to internal API clients.
type Provider interface {
	CallTimeout() time.Duration
	Workflow() workflowpb.WorkflowServiceClient
	Pipelines() pipelinepb.PipelineServiceClient
	Jobs() jobpb.JobServiceClient
	Loghub() loghubpb.LoghubClient
	Loghub2() loghub2pb.Loghub2Client
}

// Manager owns gRPC connections to internal API services and exposes typed clients.
type Manager struct {
	cfg Config

	workflowConn *grpc.ClientConn
	pipelineConn *grpc.ClientConn
	jobConn      *grpc.ClientConn
	loghubConn   *grpc.ClientConn
	loghub2Conn  *grpc.ClientConn

	workflowClient workflowpb.WorkflowServiceClient
	pipelineClient pipelinepb.PipelineServiceClient
	jobClient      jobpb.JobServiceClient
	loghubClient   loghubpb.LoghubClient
	loghub2Client  loghub2pb.Loghub2Client
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
	if m.workflowConn, err = dial(cfg.WorkflowEndpoint); err != nil {
		return nil, fmt.Errorf("connect workflow service: %w", err)
	}
	if m.pipelineConn, err = dial(cfg.PipelineEndpoint); err != nil {
		m.Close()
		return nil, fmt.Errorf("connect pipeline service: %w", err)
	}
	if m.jobConn, err = dial(cfg.JobEndpoint); err != nil {
		m.Close()
		return nil, fmt.Errorf("connect job service: %w", err)
	}
	if m.loghubConn, err = dial(cfg.LoghubEndpoint); err != nil {
		m.Close()
		return nil, fmt.Errorf("connect loghub service: %w", err)
	}
	if m.loghub2Conn, err = dial(cfg.Loghub2Endpoint); err != nil {
		m.Close()
		return nil, fmt.Errorf("connect loghub2 service: %w", err)
	}

	if m.workflowConn != nil {
		m.workflowClient = workflowpb.NewWorkflowServiceClient(m.workflowConn)
	}
	if m.pipelineConn != nil {
		m.pipelineClient = pipelinepb.NewPipelineServiceClient(m.pipelineConn)
	}
	if m.jobConn != nil {
		m.jobClient = jobpb.NewJobServiceClient(m.jobConn)
	}
	if m.loghubConn != nil {
		m.loghubClient = loghubpb.NewLoghubClient(m.loghubConn)
	}
	if m.loghub2Conn != nil {
		m.loghub2Client = loghub2pb.NewLoghub2Client(m.loghub2Conn)
	}

	return m, nil
}

// Close tears down all gRPC connections owned by the manager.
func (m *Manager) Close() error {
	var errs []error
	closers := []*grpc.ClientConn{m.workflowConn, m.pipelineConn, m.jobConn, m.loghubConn, m.loghub2Conn}
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

func (m *Manager) Workflow() workflowpb.WorkflowServiceClient {
	return m.workflowClient
}

func (m *Manager) Pipelines() pipelinepb.PipelineServiceClient {
	return m.pipelineClient
}

func (m *Manager) Jobs() jobpb.JobServiceClient {
	return m.jobClient
}

func (m *Manager) Loghub() loghubpb.LoghubClient {
	return m.loghubClient
}

func (m *Manager) Loghub2() loghub2pb.Loghub2Client {
	return m.loghub2Client
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
