package pipelines

import (
	"context"
	"fmt"
	"strings"

	"github.com/mark3labs/mcp-go/mcp"
	"github.com/mark3labs/mcp-go/server"

	pipelinepb "github.com/semaphoreio/semaphore/mcp_server/pkg/internal_api/plumber.pipeline"
	"github.com/semaphoreio/semaphore/mcp_server/pkg/internalapi"
	"github.com/semaphoreio/semaphore/mcp_server/pkg/tools/internal/shared"
)

const (
	listToolName     = "pipelines.list"
	describeToolName = "pipelines.describe"
	defaultLimit     = 20
	maxLimit         = 100
	errNoClient      = "pipeline gRPC endpoint is not configured"
)

// Register wires pipeline tooling into the MCP server.
func Register(s *server.MCPServer, api internalapi.Provider) {
	s.AddTool(newListTool(), listHandler(api))
	s.AddTool(newDescribeTool(), describeHandler(api))
}

func newListTool() mcp.Tool {
	return mcp.NewTool(
		listToolName,
		mcp.WithDescription("List pipelines for a workflow."),
		mcp.WithString(
			"workflow_id",
			mcp.Required(),
			mcp.Description("Workflow UUID to list pipelines for."),
		),
		mcp.WithString(
			"project_id",
			mcp.Description("Optional project UUID filter."),
		),
		mcp.WithString(
			"cursor",
			mcp.Description("Opaque pagination cursor returned by previous calls."),
		),
		mcp.WithNumber(
			"limit",
			mcp.Description("Maximum number of pipelines to return."),
			mcp.Min(1),
			mcp.Max(maxLimit),
			mcp.DefaultNumber(defaultLimit),
		),
	)
}

func newDescribeTool() mcp.Tool {
	return mcp.NewTool(
		describeToolName,
		mcp.WithDescription("Describe a pipeline and its blocks."),
		mcp.WithString(
			"pipeline_id",
			mcp.Required(),
			mcp.Description("Pipeline UUID to describe."),
		),
		mcp.WithBoolean(
			"detailed",
			mcp.Description("Set to true to request a detailed response."),
			func(schema map[string]any) { schema["default"] = false },
		),
	)
}

type queueSummary struct {
	ID   string `json:"id,omitempty"`
	Name string `json:"name,omitempty"`
	Type string `json:"type,omitempty"`
}

type pipelineSummary struct {
	ID             string       `json:"id"`
	Name           string       `json:"name,omitempty"`
	WorkflowID     string       `json:"workflowId,omitempty"`
	ProjectID      string       `json:"projectId,omitempty"`
	Branch         string       `json:"branch,omitempty"`
	CommitSHA      string       `json:"commitSha,omitempty"`
	State          string       `json:"state,omitempty"`
	Result         string       `json:"result,omitempty"`
	ResultReason   string       `json:"resultReason,omitempty"`
	ErrorMessage   string       `json:"errorMessage,omitempty"`
	CreatedAt      string       `json:"createdAt,omitempty"`
	RunningAt      string       `json:"runningAt,omitempty"`
	DoneAt         string       `json:"doneAt,omitempty"`
	Queue          queueSummary `json:"queue"`
	Triggerer      string       `json:"triggerer,omitempty"`
	WithAfterTask  bool         `json:"withAfterTask"`
	AfterTaskID    string       `json:"afterTaskId,omitempty"`
	PromotionOf    string       `json:"promotionOf,omitempty"`
	PartialRerunOf string       `json:"partialRerunOf,omitempty"`
}

type listResult struct {
	Pipelines  []pipelineSummary `json:"pipelines"`
	NextCursor string            `json:"nextCursor,omitempty"`
}

type blockSummary struct {
	ID             string            `json:"id"`
	Name           string            `json:"name,omitempty"`
	BuildRequestID string            `json:"buildRequestId,omitempty"`
	State          string            `json:"state,omitempty"`
	Result         string            `json:"result,omitempty"`
	ResultReason   string            `json:"resultReason,omitempty"`
	ErrorMessage   string            `json:"errorMessage,omitempty"`
	Jobs           []blockJobSummary `json:"jobs,omitempty"`
}

type blockJobSummary struct {
	Name   string `json:"name,omitempty"`
	Index  uint32 `json:"index,omitempty"`
	JobID  string `json:"jobId,omitempty"`
	Status string `json:"status,omitempty"`
	Result string `json:"result,omitempty"`
}

type describeResult struct {
	Pipeline pipelineSummary `json:"pipeline"`
	Blocks   []blockSummary  `json:"blocks,omitempty"`
}

func listHandler(api internalapi.Provider) server.ToolHandlerFunc {
	return func(ctx context.Context, req mcp.CallToolRequest) (*mcp.CallToolResult, error) {
		client := api.Pipelines()
		if client == nil {
			return mcp.NewToolResultError(errNoClient), nil
		}

		workflowID, err := req.RequireString("workflow_id")
		if err != nil {
			return mcp.NewToolResultError(err.Error()), nil
		}

		limit := req.GetInt("limit", defaultLimit)
		if limit <= 0 {
			limit = defaultLimit
		} else if limit > maxLimit {
			limit = maxLimit
		}

		request := &pipelinepb.ListKeysetRequest{
			WfId:      workflowID,
			PageSize:  int32(limit),
			PageToken: strings.TrimSpace(req.GetString("cursor", "")),
			Order:     pipelinepb.ListKeysetRequest_BY_CREATION_TIME_DESC,
			Direction: pipelinepb.ListKeysetRequest_NEXT,
		}

		if projectID := strings.TrimSpace(req.GetString("project_id", "")); projectID != "" {
			request.ProjectId = projectID
		}

		callCtx, cancel := context.WithTimeout(ctx, api.CallTimeout())
		defer cancel()

		resp, err := client.ListKeyset(callCtx, request)
		if err != nil {
			return mcp.NewToolResultError(fmt.Sprintf("pipeline list RPC failed: %v", err)), nil
		}

		pipelines := make([]pipelineSummary, 0, len(resp.GetPipelines()))
		for _, ppl := range resp.GetPipelines() {
			pipelines = append(pipelines, summarizePipeline(ppl))
		}

		result := listResult{Pipelines: pipelines}
		if token := strings.TrimSpace(resp.GetNextPageToken()); token != "" {
			result.NextCursor = token
		}

		return mcp.NewToolResultStructuredOnly(result), nil
	}
}

func describeHandler(api internalapi.Provider) server.ToolHandlerFunc {
	return func(ctx context.Context, req mcp.CallToolRequest) (*mcp.CallToolResult, error) {
		client := api.Pipelines()
		if client == nil {
			return mcp.NewToolResultError(errNoClient), nil
		}

		pipelineID, err := req.RequireString("pipeline_id")
		if err != nil {
			return mcp.NewToolResultError(err.Error()), nil
		}

		detailed := mcp.ParseBoolean(req, "detailed", false)

		callCtx, cancel := context.WithTimeout(ctx, api.CallTimeout())
		defer cancel()

		resp, err := client.Describe(callCtx, &pipelinepb.DescribeRequest{PplId: pipelineID, Detailed: detailed})
		if err != nil {
			return mcp.NewToolResultError(fmt.Sprintf("pipeline describe RPC failed: %v", err)), nil
		}

		if status := resp.GetResponseStatus(); status != nil && status.GetCode() != pipelinepb.ResponseStatus_OK {
			return mcp.NewToolResultError(strings.TrimSpace(status.GetMessage())), nil
		}

		result := describeResult{}
		if resp.GetPipeline() != nil {
			result.Pipeline = summarizePipeline(resp.GetPipeline())
		}
		if blocks := resp.GetBlocks(); len(blocks) > 0 {
			result.Blocks = make([]blockSummary, 0, len(blocks))
			for _, block := range blocks {
				result.Blocks = append(result.Blocks, summarizeBlock(block))
			}
		}

		return mcp.NewToolResultStructuredOnly(result), nil
	}
}

func summarizePipeline(ppl *pipelinepb.Pipeline) pipelineSummary {
	if ppl == nil {
		return pipelineSummary{}
	}

	return pipelineSummary{
		ID:             ppl.GetPplId(),
		Name:           ppl.GetName(),
		WorkflowID:     ppl.GetWfId(),
		ProjectID:      ppl.GetProjectId(),
		Branch:         ppl.GetBranchName(),
		CommitSHA:      ppl.GetCommitSha(),
		State:          pipelineStateToString(ppl.GetState()),
		Result:         pipelineResultToString(ppl.GetResult()),
		ResultReason:   pipelineResultReasonToString(ppl.GetResultReason()),
		ErrorMessage:   strings.TrimSpace(ppl.GetErrorDescription()),
		CreatedAt:      shared.FormatTimestamp(ppl.GetCreatedAt()),
		RunningAt:      shared.FormatTimestamp(ppl.GetRunningAt()),
		DoneAt:         shared.FormatTimestamp(ppl.GetDoneAt()),
		Queue:          summarizeQueue(ppl.GetQueue()),
		Triggerer:      summarizeTriggerer(ppl.GetTriggerer()),
		WithAfterTask:  ppl.GetWithAfterTask(),
		AfterTaskID:    ppl.GetAfterTaskId(),
		PromotionOf:    ppl.GetPromotionOf(),
		PartialRerunOf: ppl.GetPartialRerunOf(),
	}
}

func summarizeBlock(block *pipelinepb.Block) blockSummary {
	if block == nil {
		return blockSummary{}
	}

	jobs := make([]blockJobSummary, 0, len(block.GetJobs()))
	for _, job := range block.GetJobs() {
		jobs = append(jobs, blockJobSummary{
			Name:   job.GetName(),
			Index:  job.GetIndex(),
			JobID:  job.GetJobId(),
			Status: job.GetStatus(),
			Result: job.GetResult(),
		})
	}

	return blockSummary{
		ID:             block.GetBlockId(),
		Name:           block.GetName(),
		BuildRequestID: block.GetBuildReqId(),
		State:          blockStateToString(block.GetState()),
		Result:         blockResultToString(block.GetResult()),
		ResultReason:   blockResultReasonToString(block.GetResultReason()),
		ErrorMessage:   strings.TrimSpace(block.GetErrorDescription()),
		Jobs:           jobs,
	}
}

func pipelineStateToString(state pipelinepb.Pipeline_State) string {
	if name, ok := pipelinepb.Pipeline_State_name[int32(state)]; ok {
		return strings.ToLower(name)
	}
	return "unspecified"
}

func pipelineResultToString(result pipelinepb.Pipeline_Result) string {
	if name, ok := pipelinepb.Pipeline_Result_name[int32(result)]; ok {
		return strings.ToLower(name)
	}
	return "unknown"
}

func pipelineResultReasonToString(reason pipelinepb.Pipeline_ResultReason) string {
	if name, ok := pipelinepb.Pipeline_ResultReason_name[int32(reason)]; ok {
		return strings.ToLower(name)
	}
	return "unspecified"
}

func summarizeQueue(q *pipelinepb.Queue) queueSummary {
	if q == nil {
		return queueSummary{}
	}
	return queueSummary{
		ID:   q.GetQueueId(),
		Name: q.GetName(),
		Type: queueTypeToString(q.GetType()),
	}
}

func queueTypeToString(t pipelinepb.QueueType) string {
	if name, ok := pipelinepb.QueueType_name[int32(t)]; ok {
		return strings.ToLower(name)
	}
	return "unspecified"
}

func summarizeTriggerer(triggerer *pipelinepb.Triggerer) string {
	if triggerer == nil {
		return ""
	}
	if name, ok := pipelinepb.TriggeredBy_name[int32(triggerer.GetPplTriggeredBy())]; ok {
		return strings.ToLower(name)
	}
	return ""
}

func blockStateToString(state pipelinepb.Block_State) string {
	if name, ok := pipelinepb.Block_State_name[int32(state)]; ok {
		return strings.ToLower(name)
	}
	return "unspecified"
}

func blockResultToString(result pipelinepb.Block_Result) string {
	if name, ok := pipelinepb.Block_Result_name[int32(result)]; ok {
		return strings.ToLower(name)
	}
	return "unknown"
}

func blockResultReasonToString(reason pipelinepb.Block_ResultReason) string {
	if name, ok := pipelinepb.Block_ResultReason_name[int32(reason)]; ok {
		return strings.ToLower(name)
	}
	return "unspecified"
}
