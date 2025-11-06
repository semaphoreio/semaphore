package jobs

import (
	"context"
	"fmt"
	"strings"

	"github.com/sirupsen/logrus"

	jobpb "github.com/semaphoreio/semaphore/mcp_server/pkg/internal_api/server_farm.job"
	"github.com/semaphoreio/semaphore/mcp_server/pkg/internalapi"
	"github.com/semaphoreio/semaphore/mcp_server/pkg/logging"
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
		logging.ForComponent("rpc").
			WithFields(logrus.Fields{
				"rpc":   "jobs.Describe",
				"jobId": jobID,
			}).
			WithError(err).
			Warn("describe job returned non-OK status")
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

func formatJobMarkdown(summary jobSummary, mode string) string {
	mb := shared.NewMarkdownBuilder()

	title := summary.Name
	if strings.TrimSpace(title) == "" {
		title = fmt.Sprintf("Job %s", summary.ID)
	} else {
		title = fmt.Sprintf("%s (%s)", summary.Name, summary.ID)
	}
	mb.H1(title)

	mb.KeyValue("Job ID", fmt.Sprintf("`%s`", summary.ID))
	if summary.PipelineID != "" {
		mb.KeyValue("Pipeline ID", fmt.Sprintf("`%s`", summary.PipelineID))
	}
	if summary.ProjectID != "" {
		mb.KeyValue("Project ID", fmt.Sprintf("`%s`", summary.ProjectID))
	}
	if summary.OrganizationID != "" {
		mb.KeyValue("Organization ID", fmt.Sprintf("`%s`", summary.OrganizationID))
	}
	if summary.BranchID != "" {
		mb.KeyValue("Branch ID", fmt.Sprintf("`%s`", summary.BranchID))
	}
	if summary.HookID != "" {
		mb.KeyValue("Hook ID", fmt.Sprintf("`%s`", summary.HookID))
	}

	resultDisplay := strings.TrimSpace(summary.Result)
	if resultDisplay != "" {
		mb.KeyValue("Result", fmt.Sprintf("%s %s", shared.StatusIcon(resultDisplay), titleCase(resultDisplay)))
	}
	if summary.State != "" {
		mb.KeyValue("State", titleCase(summary.State))
	}

	mb.KeyValue("Self-hosted", shared.FormatBoolean(summary.SelfHosted, "Yes", "No"))
	if summary.IsDebugJob {
		mb.ListItem("🛠 Debug job")
	}
	if summary.DebugUserID != "" {
		mb.KeyValue("Debug user ID", fmt.Sprintf("`%s`", summary.DebugUserID))
	}

	if summary.FailureReason != "" {
		mb.Paragraph(fmt.Sprintf("⚠️ **Failure reason**: %s", summary.FailureReason))
	}

	mb.Newline()
	mb.H2("Timeline")
	appendTimeline(mb, summary.Timeline)

	if mode == "detailed" {
		mb.Line()
		mb.H2("Agent & Machine")
		if summary.MachineType != "" {
			mb.KeyValue("Machine Type", summary.MachineType)
		}
		if summary.MachineImage != "" {
			mb.KeyValue("Machine Image", summary.MachineImage)
		}
		if summary.AgentName != "" {
			mb.KeyValue("Agent Name", summary.AgentName)
		}
		if summary.AgentHost != "" {
			mb.KeyValue("Agent Host", summary.AgentHost)
		}
		if summary.AgentID != "" {
			mb.KeyValue("Agent ID", fmt.Sprintf("`%s`", summary.AgentID))
		}
		mb.KeyValue("Priority", fmt.Sprintf("%d", summary.Priority))
	}

	mb.Line()

	return mb.String()
}

func appendTimeline(mb *shared.MarkdownBuilder, timeline timelineSummary) {
	if timeline == (timelineSummary{}) {
		mb.Paragraph("No timeline information reported.")
		return
	}
	if timeline.CreatedAt != "" {
		mb.KeyValue("Created", timeline.CreatedAt)
	}
	if timeline.EnqueuedAt != "" {
		mb.KeyValue("Enqueued", timeline.EnqueuedAt)
	}
	if timeline.StartedAt != "" {
		mb.KeyValue("Started", timeline.StartedAt)
	}
	if timeline.ExecutionStartedAt != "" {
		mb.KeyValue("Execution Started", timeline.ExecutionStartedAt)
	}
	if timeline.ExecutionFinishedAt != "" {
		mb.KeyValue("Execution Finished", timeline.ExecutionFinishedAt)
	}
	if timeline.FinishedAt != "" {
		mb.KeyValue("Finished", timeline.FinishedAt)
	}
}

func titleCase(value string) string {
	value = strings.TrimSpace(strings.ToLower(value))
	if value == "" {
		return ""
	}
	parts := strings.Split(value, "_")
	for i, part := range parts {
		if part == "" {
			continue
		}
		parts[i] = strings.ToUpper(part[:1]) + part[1:]
	}
	return strings.Join(parts, " ")
}
