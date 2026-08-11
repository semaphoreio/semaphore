// Package clients provides shared API client functions for MCP tools.
package clients

import (
	"context"
	"fmt"
	"strings"

	"github.com/google/uuid"
	"github.com/sirupsen/logrus"

	pipelinepb "github.com/semaphoreio/semaphore/mcp_server/pkg/internal_api/plumber.pipeline"
	projecthubpb "github.com/semaphoreio/semaphore/mcp_server/pkg/internal_api/projecthub"
	jobpb "github.com/semaphoreio/semaphore/mcp_server/pkg/internal_api/server_farm.job"
	taskpb "github.com/semaphoreio/semaphore/mcp_server/pkg/internal_api/task"
	"github.com/semaphoreio/semaphore/mcp_server/pkg/internalapi"
	"github.com/semaphoreio/semaphore/mcp_server/pkg/logging"
	"github.com/semaphoreio/semaphore/mcp_server/pkg/tools/internal/shared"
)

// DescribePipeline fetches pipeline details by ID.
// Returns the full DescribeResponse so callers can access both Pipeline and Blocks.
func DescribePipeline(ctx context.Context, api internalapi.Provider, pipelineID string, detailed bool) (*pipelinepb.DescribeResponse, error) {
	client := api.Pipelines()
	if client == nil {
		return nil, fmt.Errorf("pipeline gRPC endpoint is not configured")
	}
	callCtx, cancel := context.WithTimeout(ctx, api.CallTimeout())
	defer cancel()

	resp, err := client.Describe(callCtx, &pipelinepb.DescribeRequest{PplId: pipelineID, Detailed: detailed})
	if err != nil {
		logging.ForComponent("rpc").
			WithFields(logrus.Fields{
				"rpc":        "pipeline.Describe",
				"pipelineId": pipelineID,
			}).
			WithError(err).
			Error("pipeline describe RPC failed")
		return nil, fmt.Errorf("pipeline describe RPC failed: %w", err)
	}
	if status := resp.GetResponseStatus(); status != nil && status.GetCode() != pipelinepb.ResponseStatus_OK {
		message := strings.TrimSpace(status.GetMessage())
		if message == "" {
			message = "pipeline describe returned non-OK status"
		}
		return nil, fmt.Errorf("pipeline describe failed: %s", message)
	}
	if resp.GetPipeline() == nil {
		return nil, fmt.Errorf("pipeline describe returned no pipeline payload")
	}
	return resp, nil
}

// DescribePipelineTopology fetches the topology for a pipeline.
// Note: after-pipeline entries in topology contain job names, not Zebra job IDs.
func DescribePipelineTopology(ctx context.Context, api internalapi.Provider, pipelineID string) (*pipelinepb.DescribeTopologyResponse, error) {
	client := api.Pipelines()
	if client == nil {
		return nil, fmt.Errorf("pipeline gRPC endpoint is not configured")
	}
	callCtx, cancel := context.WithTimeout(ctx, api.CallTimeout())
	defer cancel()

	resp, err := client.DescribeTopology(callCtx, &pipelinepb.DescribeTopologyRequest{PplId: pipelineID})
	if err != nil {
		logging.ForComponent("rpc").
			WithFields(logrus.Fields{
				"rpc":        "pipeline.DescribeTopology",
				"pipelineId": pipelineID,
			}).
			WithError(err).
			Error("pipeline describe topology RPC failed")
		return nil, fmt.Errorf("pipeline describe topology RPC failed: %w", err)
	}
	if status := resp.GetStatus(); status != nil && status.GetCode() != pipelinepb.ResponseStatus_OK {
		message := strings.TrimSpace(status.GetMessage())
		if message == "" {
			message = "pipeline describe topology returned non-OK status"
		}
		return nil, fmt.Errorf("pipeline describe topology failed: %s", message)
	}
	return resp, nil
}

// DescribeTasks fetches task details for the provided task IDs.
func DescribeTasks(ctx context.Context, api internalapi.Provider, taskIDs []string) ([]*taskpb.Task, error) {
	client := api.Task()
	if client == nil {
		return nil, fmt.Errorf("task gRPC endpoint is not configured")
	}

	cleanIDs := make([]string, 0, len(taskIDs))
	for _, id := range taskIDs {
		id = strings.TrimSpace(id)
		if id == "" {
			continue
		}
		cleanIDs = append(cleanIDs, id)
	}
	if len(cleanIDs) == 0 {
		return nil, nil
	}

	callCtx, cancel := context.WithTimeout(ctx, api.CallTimeout())
	defer cancel()

	resp, err := client.DescribeMany(callCtx, &taskpb.DescribeManyRequest{TaskIds: cleanIDs})
	if err != nil {
		logging.ForComponent("rpc").
			WithFields(logrus.Fields{
				"rpc":     "task.DescribeMany",
				"taskIds": strings.Join(cleanIDs, ","),
			}).
			WithError(err).
			Error("task describe many RPC failed")
		return nil, fmt.Errorf("task describe many RPC failed: %w", err)
	}

	return resp.GetTasks(), nil
}

// DescribeProject fetches project details with proper auth metadata.
func DescribeProject(ctx context.Context, api internalapi.Provider, orgID, userID, projectID string) (*projecthubpb.Project, error) {
	client := api.Projects()
	if client == nil {
		return nil, fmt.Errorf("project gRPC endpoint is not configured")
	}
	callCtx, cancel := context.WithTimeout(ctx, api.CallTimeout())
	defer cancel()

	req := &projecthubpb.DescribeRequest{
		Id: projectID,
		Metadata: &projecthubpb.RequestMeta{
			ApiVersion: "v1alpha",
			Kind:       "Project",
			OrgId:      strings.TrimSpace(orgID),
			UserId:     strings.TrimSpace(userID),
			ReqId:      uuid.NewString(),
		},
	}

	resp, err := client.Describe(callCtx, req)
	if err != nil {
		logging.ForComponent("rpc").
			WithFields(logrus.Fields{
				"rpc":       "project.Describe",
				"projectId": projectID,
				"orgId":     orgID,
				"userId":    userID,
			}).
			WithError(err).
			Error("describe project RPC failed")
		return nil, fmt.Errorf("describe project RPC failed: %w", err)
	}
	if err := shared.CheckProjectResponseMeta(resp.GetMetadata()); err != nil {
		return nil, err
	}
	if resp.GetProject() == nil {
		return nil, fmt.Errorf("describe project returned no project payload")
	}
	return resp.GetProject(), nil
}

// DescribeJob fetches job details by ID.
func DescribeJob(ctx context.Context, api internalapi.Provider, jobID string) (*jobpb.Job, error) {
	client := api.Jobs()
	if client == nil {
		return nil, fmt.Errorf("job gRPC endpoint is not configured")
	}

	callCtx, cancel := context.WithTimeout(ctx, api.CallTimeout())
	defer cancel()

	resp, err := client.Describe(callCtx, &jobpb.DescribeRequest{JobId: jobID})
	if err != nil {
		logging.ForComponent("rpc").
			WithFields(logrus.Fields{
				"rpc":   "jobs.Describe",
				"jobId": jobID,
			}).
			WithError(err).
			Error("gRPC call failed")
		return nil, fmt.Errorf("describe job RPC failed: %w", err)
	}

	if err := shared.CheckResponseStatus(resp.GetStatus()); err != nil {
		return nil, err
	}

	job := resp.GetJob()
	if job == nil {
		return nil, fmt.Errorf("describe job returned no job payload")
	}

	return job, nil
}
