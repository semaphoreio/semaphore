package pipelines

import (
	"context"
	"fmt"
	"strings"

	"github.com/mark3labs/mcp-go/mcp"
	"github.com/mark3labs/mcp-go/server"
	"github.com/sirupsen/logrus"

	pipelinepb "github.com/semaphoreio/semaphore/mcp_server/pkg/internal_api/plumber.pipeline"
	"github.com/semaphoreio/semaphore/mcp_server/pkg/internalapi"
	"github.com/semaphoreio/semaphore/mcp_server/pkg/logging"
	"github.com/semaphoreio/semaphore/mcp_server/pkg/tools/internal/shared"
)

const (
	listToolName       = "workflow_pipelines_list"
	legacyListToolName = "pipelines_list"
	defaultLimit       = 20
	maxLimit           = 100
	errNoClient        = "pipeline gRPC endpoint is not configured"
)

const (
	listToolDescription = `List pipelines associated with a workflow (most recent first).

This is typically called after discovering workflows via project_workflows_search. Use it to:
- Identify pipeline IDs before drilling into jobs with jobs_describe or jobs_logs
- Check which branch/commit triggered each pipeline
- Investigate promotions, reruns, and queue usage

Filters & pagination:
- organization_id (required): UUID of the organization context (cache it after calling core_organizations_list)
- workflow_id (required): UUID of the workflow whose pipelines you need
- project_id (optional): narrow results when workflows span multiple projects
- cursor: use the previous response’s nextCursor to fetch older pipelines
- limit: number of pipelines to return (default 20, max 100)

Response modes:
- summary (default): pipeline ID, state, result, branch, queue, triggerer, timestamps
- detailed: includes rerun linkage, promotion metadata, and queue details expanded

Example:
- workflow_pipelines_list(workflow_id="...", limit=5)
- workflow_pipelines_list(workflow_id="...", project_id="...", mode="detailed")
- workflow_pipelines_list(workflow_id="...", cursor="opaque-token")
`
)

// Register wires pipeline tooling into the MCP server.
func Register(s *server.MCPServer, api internalapi.Provider) {
	list := listHandler(api)

	s.AddTool(newListTool(listToolName, listToolDescription), list)
	s.AddTool(newListTool(legacyListToolName, "Legacy alias for workflow_pipelines_list. Prefer workflow_pipelines_list for full documentation and Markdown output."), list)
}

func newListTool(name, description string) mcp.Tool {
	return mcp.NewTool(
		name,
		mcp.WithDescription(description),
		mcp.WithString(
			"workflow_id",
			mcp.Required(),
			mcp.Description("Workflow UUID to list pipelines for (format: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx)."),
			mcp.Pattern(`^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$`),
		),
		mcp.WithString(
			"organization_id",
			mcp.Required(),
			mcp.Description("Organization UUID that owns the workflow. Keep it consistent with core_organizations_list results."),
			mcp.Pattern(`^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$`),
		),
		mcp.WithString(
			"project_id",
			mcp.Description("Optional project UUID filter to restrict results (format: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx)."),
			mcp.Pattern(`^$|^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$`),
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
		mcp.WithString(
			"mode",
			mcp.Description("Response detail level. Use 'summary' for quick scans or 'detailed' for rerun/promotion context."),
			mcp.Enum("summary", "detailed"),
			mcp.DefaultString("summary"),
		),
		mcp.WithReadOnlyHintAnnotation(true),
		mcp.WithIdempotentHintAnnotation(true),
		mcp.WithOpenWorldHintAnnotation(true),
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

func listHandler(api internalapi.Provider) server.ToolHandlerFunc {
	return func(ctx context.Context, req mcp.CallToolRequest) (*mcp.CallToolResult, error) {
		client := api.Pipelines()
		if client == nil {
			return mcp.NewToolResultError(errNoClient), nil
		}

		orgIDRaw, err := req.RequireString("organization_id")
		if err != nil {
			return mcp.NewToolResultError("organization_id is required. Use core_organizations_list to select an organization before listing pipelines."), nil
		}
		orgID := strings.TrimSpace(orgIDRaw)
		if err := shared.ValidateUUID(orgID, "organization_id"); err != nil {
			return mcp.NewToolResultError(err.Error()), nil
		}

		workflowIDRaw, err := req.RequireString("workflow_id")
		if err != nil {
			return mcp.NewToolResultError("workflow_id is required. Provide the workflow UUID returned by project_workflows_search."), nil
		}

		workflowID := strings.TrimSpace(workflowIDRaw)
		if err := shared.ValidateUUID(workflowID, "workflow_id"); err != nil {
			return mcp.NewToolResultError(err.Error()), nil
		}

		projectID := strings.TrimSpace(req.GetString("project_id", ""))
		if projectID != "" {
			if err := shared.ValidateUUID(projectID, "project_id"); err != nil {
				return mcp.NewToolResultError(err.Error()), nil
			}
		}

		mode, err := shared.NormalizeMode(req.GetString("mode", "summary"))
		if err != nil {
			return mcp.NewToolResultError(fmt.Sprintf("Invalid mode parameter: %v", err)), nil
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

		if projectID != "" {
			request.ProjectId = projectID
		}

		callCtx, cancel := context.WithTimeout(ctx, api.CallTimeout())
		defer cancel()

		resp, err := client.ListKeyset(callCtx, request)
		if err != nil {
			logging.ForComponent("rpc").
				WithFields(logrus.Fields{
					"rpc":            "pipeline.ListKeyset",
					"workflowId":     workflowID,
					"projectId":      projectID,
					"organizationId": orgID,
					"limit":          limit,
					"cursor":         request.PageToken,
					"mode":           mode,
				}).
				WithError(err).
				Error("gRPC call failed")
			return mcp.NewToolResultError(fmt.Sprintf(`Pipeline list RPC failed: %v

Check that:
- The workflow still exists and you have permission to access it
- INTERNAL_API_URL_PLUMBER (or MCP_PIPELINE_GRPC_ENDPOINT) is reachable
- You are not paginating beyond available results (try removing cursor)
`, err)), nil
		}

		pipelines := make([]pipelineSummary, 0, len(resp.GetPipelines()))
		for _, ppl := range resp.GetPipelines() {
			pipelines = append(pipelines, summarizePipeline(ppl))
		}

		result := listResult{Pipelines: pipelines}
		if token := strings.TrimSpace(resp.GetNextPageToken()); token != "" {
			result.NextCursor = token
		}

		markdown := formatPipelineListMarkdown(result, mode, workflowID, projectID, orgID, limit)
		markdown = shared.TruncateResponse(markdown, shared.MaxResponseChars)

		return &mcp.CallToolResult{
			Content: []mcp.Content{
				mcp.NewTextContent(markdown),
			},
			StructuredContent: result,
		}, nil
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

func formatPipelineListMarkdown(result listResult, mode, workflowID, projectID, orgID string, limit int) string {
	mb := shared.NewMarkdownBuilder()

	header := fmt.Sprintf("Pipelines for Workflow %s (%d returned)", workflowID, len(result.Pipelines))
	mb.H1(header)
	filters := []string{fmt.Sprintf("limit=%d", limit), fmt.Sprintf("organizationId=%s", orgID)}
	if projectID != "" {
		filters = append(filters, fmt.Sprintf(`project_id="%s"`, projectID))
	}
	if len(filters) > 0 {
		mb.Paragraph("Filters: " + strings.Join(filters, ", "))
	}

	if len(result.Pipelines) == 0 {
		mb.Paragraph("No pipelines found for the provided workflow and filters.")
		mb.Paragraph("**Suggestions:**")
		mb.ListItem("Verify the workflow still exists and has completed pipelines.")
		mb.ListItem("Remove the project_id filter if one was provided.")
		mb.ListItem("Use project_workflows_search to confirm the workflow status.")
		return mb.String()
	}

	for i, pipeline := range result.Pipelines {
		if i > 0 {
			mb.Line()
		}

		name := strings.TrimSpace(pipeline.Name)
		if name == "" {
			name = pipeline.ID
		}
		mb.H2(fmt.Sprintf("%s (%s)", name, pipeline.ID))

		if pipeline.State != "" {
			mb.KeyValue("State", fmt.Sprintf("%s %s", shared.StatusIcon(pipeline.State), titleCase(pipeline.State)))
		}
		if pipeline.Result != "" {
			resultLine := titleCase(pipeline.Result)
			if pipeline.ResultReason != "" {
				resultLine = fmt.Sprintf("%s (reason: %s)", resultLine, titleCase(pipeline.ResultReason))
			}
			mb.KeyValue("Result", fmt.Sprintf("%s %s", shared.StatusIcon(pipeline.Result), resultLine))
		}
		if pipeline.ErrorMessage != "" {
			mb.Paragraph(fmt.Sprintf("⚠️ **Error**: %s", pipeline.ErrorMessage))
		}

		if pipeline.Branch != "" {
			mb.KeyValue("Branch", pipeline.Branch)
		}
		if pipeline.CommitSHA != "" {
			mb.KeyValue("Commit", shortenCommit(pipeline.CommitSHA))
		}
		if pipeline.Triggerer != "" {
			mb.KeyValue("Triggered By", titleCase(pipeline.Triggerer))
		}
		if pipeline.Queue.Name != "" {
			mb.KeyValue("Queue", fmt.Sprintf("%s (%s)", pipeline.Queue.Name, titleCase(pipeline.Queue.Type)))
		}
		if pipeline.CreatedAt != "" {
			mb.KeyValue("Created", pipeline.CreatedAt)
		}
		if pipeline.RunningAt != "" {
			mb.KeyValue("Running Since", pipeline.RunningAt)
		}
		if pipeline.DoneAt != "" {
			mb.KeyValue("Completed At", pipeline.DoneAt)
		}

		if mode == "detailed" {
			if pipeline.WithAfterTask {
				mb.ListItem("🔁 Includes after-task stage")
			}
			if pipeline.AfterTaskID != "" {
				mb.KeyValue("After Task ID", fmt.Sprintf("`%s`", pipeline.AfterTaskID))
			}
			if pipeline.PromotionOf != "" {
				mb.KeyValue("Promotion Of", fmt.Sprintf("`%s`", pipeline.PromotionOf))
			}
			if pipeline.PartialRerunOf != "" {
				mb.KeyValue("Partial Rerun Of", fmt.Sprintf("`%s`", pipeline.PartialRerunOf))
			}
		}

		mb.Newline()
		mb.Paragraph("Next: inspect individual jobs with `jobs_logs(job_id=\"...\")` or summarize them via `jobs_describe(job_id=\"...\")`.")
	}

	mb.Line()
	if result.NextCursor != "" {
		mb.Paragraph(fmt.Sprintf("📄 **More pipelines available.** Continue with `cursor=\"%s\"` to fetch older runs.", result.NextCursor))
	} else {
		mb.Paragraph("End of pipelines for the current filters.")
	}

	return mb.String()
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

func shortenCommit(sha string) string {
	sha = strings.TrimSpace(sha)
	if len(sha) > 12 {
		return sha[:12]
	}
	return sha
}
