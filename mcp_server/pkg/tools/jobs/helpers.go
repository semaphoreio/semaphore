package jobs

import (
	"context"
	"fmt"
	"strings"

	jobpb "github.com/semaphoreio/semaphore/mcp_server/pkg/internal_api/server_farm.job"
	"github.com/semaphoreio/semaphore/mcp_server/pkg/internalapi"
	"github.com/semaphoreio/semaphore/mcp_server/pkg/tools/internal/shared"
)

func fetchJob(ctx context.Context, api internalapi.Provider, jobID string) (*jobpb.Job, error) {
	client := api.Jobs()
	if client == nil {
		return nil, fmt.Errorf("job gRPC endpoint is not configured")
	}

	callCtx, cancel := context.WithTimeout(ctx, api.CallTimeout())
	defer cancel()

	resp, err := client.Describe(callCtx, &jobpb.DescribeRequest{JobId: jobID})
	if err != nil {
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

func jobStateToString(state jobpb.Job_State) string {
	if name, ok := jobpb.Job_State_name[int32(state)]; ok {
		return strings.ToLower(name)
	}
	return "unspecified"
}

func jobResultToString(result jobpb.Job_Result) string {
	if name, ok := jobpb.Job_Result_name[int32(result)]; ok {
		return strings.ToLower(name)
	}
	return "unknown"
}

type jobSummary struct {
	ID             string          `json:"id"`
	Name           string          `json:"name,omitempty"`
	PipelineID     string          `json:"pipelineId,omitempty"`
	BuildRequestID string          `json:"buildRequestId,omitempty"`
	ProjectID      string          `json:"projectId,omitempty"`
	OrganizationID string          `json:"organizationId,omitempty"`
	BranchID       string          `json:"branchId,omitempty"`
	HookID         string          `json:"hookId,omitempty"`
	State          string          `json:"state,omitempty"`
	Result         string          `json:"result,omitempty"`
	FailureReason  string          `json:"failureReason,omitempty"`
	MachineType    string          `json:"machineType,omitempty"`
	MachineImage   string          `json:"machineImage,omitempty"`
	AgentHost      string          `json:"agentHost,omitempty"`
	AgentName      string          `json:"agentName,omitempty"`
	AgentID        string          `json:"agentId,omitempty"`
	Priority       int32           `json:"priority,omitempty"`
	IsDebugJob     bool            `json:"debugJob"`
	DebugUserID    string          `json:"debugUserId,omitempty"`
	SelfHosted     bool            `json:"selfHosted"`
	Timeline       timelineSummary `json:"timeline"`
}

type timelineSummary struct {
	CreatedAt           string `json:"createdAt,omitempty"`
	EnqueuedAt          string `json:"enqueuedAt,omitempty"`
	StartedAt           string `json:"startedAt,omitempty"`
	FinishedAt          string `json:"finishedAt,omitempty"`
	ExecutionStartedAt  string `json:"executionStartedAt,omitempty"`
	ExecutionFinishedAt string `json:"executionFinishedAt,omitempty"`
}

func summarizeJob(job *jobpb.Job) jobSummary {
	var timeline timelineSummary
	if job.GetTimeline() != nil {
		tl := job.GetTimeline()
		timeline = timelineSummary{
			CreatedAt:           shared.FormatTimestamp(tl.GetCreatedAt()),
			EnqueuedAt:          shared.FormatTimestamp(tl.GetEnqueuedAt()),
			StartedAt:           shared.FormatTimestamp(tl.GetStartedAt()),
			FinishedAt:          shared.FormatTimestamp(tl.GetFinishedAt()),
			ExecutionStartedAt:  shared.FormatTimestamp(tl.GetExecutionStartedAt()),
			ExecutionFinishedAt: shared.FormatTimestamp(tl.GetExecutionFinishedAt()),
		}
	}

	return jobSummary{
		ID:             job.GetId(),
		Name:           job.GetName(),
		PipelineID:     job.GetPplId(),
		BuildRequestID: job.GetBuildReqId(),
		ProjectID:      job.GetProjectId(),
		OrganizationID: job.GetOrganizationId(),
		BranchID:       job.GetBranchId(),
		HookID:         job.GetHookId(),
		State:          jobStateToString(job.GetState()),
		Result:         jobResultToString(job.GetResult()),
		FailureReason:  strings.TrimSpace(job.GetFailureReason()),
		MachineType:    job.GetMachineType(),
		MachineImage:   job.GetMachineOsImage(),
		AgentHost:      job.GetAgentHost(),
		AgentName:      job.GetAgentName(),
		AgentID:        job.GetAgentId(),
		Priority:       job.GetPriority(),
		IsDebugJob:     job.GetIsDebugJob(),
		DebugUserID:    job.GetDebugUserId(),
		SelfHosted:     job.GetSelfHosted(),
		Timeline:       timeline,
	}
}
