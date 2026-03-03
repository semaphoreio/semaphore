package pipelines

import (
	"context"
	"errors"
	"fmt"
	"strings"

	"github.com/mark3labs/mcp-go/mcp"
	"github.com/mark3labs/mcp-go/server"
	"github.com/sirupsen/logrus"

	"github.com/semaphoreio/semaphore/mcp_server/pkg/authz"
	pipelinepb "github.com/semaphoreio/semaphore/mcp_server/pkg/internal_api/plumber.pipeline"
	"github.com/semaphoreio/semaphore/mcp_server/pkg/internalapi"
	"github.com/semaphoreio/semaphore/mcp_server/pkg/logging"
	"github.com/semaphoreio/semaphore/mcp_server/pkg/tools/internal/clients"
	"github.com/semaphoreio/semaphore/mcp_server/pkg/tools/internal/shared"
	"github.com/semaphoreio/semaphore/mcp_server/pkg/utils"
)

const (
	listToolName          = "pipelines_list"
	jobsToolName          = "pipeline_jobs"
	defaultLimit          = 20
	maxLimit              = 100
	errNoClient           = "pipeline gRPC endpoint is not configured"
	projectViewPermission = "project.view"
)

func listFullDescription() string {
	return `List pipelines associated with a workflow (most recent first).

This is typically called after discovering workflows via workflows_search. Use it to:
- Identify pipeline IDs before drilling into jobs with jobs_describe or jobs_logs
- Check which branch/commit triggered each pipeline
- Investigate promotions, reruns, and queue usage

Filters & pagination:
- organization_id (required): UUID of the organization context (cache it after calling organizations_list)
- workflow_id (required): UUID of the workflow whose pipelines you need
- project_id (optional): narrow results when workflows span multiple projects
- cursor: use the previous response's nextCursor to fetch older pipelines
- limit: number of pipelines to return (default 20, max 100)

Response modes:
- summary (default): pipeline ID, state, result, branch, queue, triggerer, timestamps
- detailed: includes rerun linkage, promotion metadata, and queue details expanded

Examples:
1. List recent pipelines for a workflow:
   pipelines_list(workflow_id="...", organization_id="...", limit=5)

2. Get detailed pipeline info:
   pipelines_list(workflow_id="...", organization_id="...", mode="detailed")

3. Paginate through older pipelines:
   pipelines_list(workflow_id="...", organization_id="...", cursor="opaque-token")

4. Filter by project ID:
   pipelines_list(workflow_id="...", organization_id="...", project_id="...", limit=10)
`
}

func jobsFullDescription() string {
	return `List jobs belonging to a specific pipeline.

Use this after discovering a pipeline via pipelines_list when you need job IDs for follow-up calls (jobs_describe, jobs_logs).

Inputs:
- organization_id (required): UUID of the organization context (cache it after calling organizations_list).
- pipeline_id (required): UUID of the pipeline whose jobs you need.
- mode (optional): "summary" (default) or "detailed".

Response:
- summary: Block headings with job names and IDs.
- detailed: Adds job status/result, block state, and pipeline metadata.

Examples:
1. List jobs for a pipeline:
   pipeline_jobs(pipeline_id="...", organization_id="...")

2. Get detailed job information:
   pipeline_jobs(pipeline_id="...", organization_id="...", mode="detailed")
`
}

// Register wires pipeline tooling into the MCP server.
func Register(s *server.MCPServer, api internalapi.Provider) {
	list := listHandler(api)
	jobs := jobsHandler(api)

	s.AddTool(newListTool(listToolName, listFullDescription()), list)
	s.AddTool(newJobsTool(jobsToolName, jobsFullDescription()), jobs)
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
			mcp.Description("Organization UUID that owns the workflow. Keep it consistent with semaphore_organizations_list results."),
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

func newJobsTool(name, description string) mcp.Tool {
	return mcp.NewTool(
		name,
		mcp.WithDescription(description),
		mcp.WithString(
			"pipeline_id",
			mcp.Required(),
			mcp.Description("Pipeline UUID to inspect (format: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx)."),
			mcp.Pattern(`^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$`),
		),
		mcp.WithString(
			"organization_id",
			mcp.Required(),
			mcp.Description("Organization UUID that owns the pipeline. Cache it after calling semaphore_organizations_list."),
			mcp.Pattern(`^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$`),
		),
		mcp.WithString(
			"mode",
			mcp.Description("Response detail level. Use 'summary' for concise output; 'detailed' adds job status and block metadata."),
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
	OrganizationID string       `json:"organizationId,omitempty"`
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

type pipelineJobEntry struct {
	JobID     string `json:"jobId"`
	Name      string `json:"name,omitempty"`
	BlockID   string `json:"blockId,omitempty"`
	BlockName string `json:"blockName,omitempty"`
	Index     uint32 `json:"index,omitempty"`
	Status    string `json:"status,omitempty"`
	Result    string `json:"result,omitempty"`
	Error     string `json:"error,omitempty"`
}

type blockJobGroup struct {
	ID     string             `json:"blockId"`
	Name   string             `json:"blockName,omitempty"`
	State  string             `json:"state,omitempty"`
	Result string             `json:"result,omitempty"`
	Jobs   []pipelineJobEntry `json:"jobs,omitempty"`
}

type jobsListResult struct {
	Pipeline pipelineSummary    `json:"pipeline"`
	Blocks   []blockJobGroup    `json:"blocks"`
	Jobs     []pipelineJobEntry `json:"jobs"`
	JobCount int                `json:"jobCount"`
}

func listHandler(api internalapi.Provider) server.ToolHandlerFunc {
	return func(ctx context.Context, req mcp.CallToolRequest) (*mcp.CallToolResult, error) {
		client := api.Pipelines()
		if client == nil {
			return mcp.NewToolResultError(errNoClient), nil
		}

		orgIDRaw, err := req.RequireString("organization_id")
		if err != nil {
			return mcp.NewToolResultError("organization_id is required. Use organizations_list to select an organization before listing pipelines."), nil
		}
		orgID := strings.TrimSpace(orgIDRaw)
		if err := shared.ValidateUUID(orgID, "organization_id"); err != nil {
			return mcp.NewToolResultError(err.Error()), nil
		}

		tracker := shared.TrackToolExecution(ctx, listToolName, orgID)
		defer tracker.Cleanup()

		if err := shared.EnsureReadToolsFeature(ctx, api, orgID); err != nil {
			return mcp.NewToolResultError(err.Error()), nil
		}

		workflowIDRaw, err := req.RequireString("workflow_id")
		if err != nil {
			return mcp.NewToolResultError("workflow_id is required. Provide the workflow UUID returned by workflows_search."), nil
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

		userID := strings.ToLower(strings.TrimSpace(req.Header.Get("X-Semaphore-User-ID")))
		if err := shared.ValidateUUID(userID, "x-semaphore-user-id header"); err != nil {
			return mcp.NewToolResultError(fmt.Sprintf(`%v

The authentication layer must inject the X-Semaphore-User-ID header so we can enforce project permissions for pipelines.

Troubleshooting:
- Ensure requests pass through the authenticated proxy
- Verify the header value is a UUID (xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx)
- Retry once the header is present`, err)), nil
		}

		if projectID != "" {
			if err := authz.CheckProjectPermission(ctx, api, userID, orgID, projectID, projectViewPermission); err != nil {
				return shared.ProjectAuthorizationError(err, orgID, projectID, projectViewPermission), nil
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

		pageSize, err := utils.IntToInt32(limit, "limit")
		if err != nil {
			return mcp.NewToolResultError(err.Error()), nil
		}

		cursorRaw := req.GetString("cursor", "")
		cursor, err := shared.SanitizeCursorToken(cursorRaw, "cursor")
		if err != nil {
			return mcp.NewToolResultError(err.Error()), nil
		}

		request := &pipelinepb.ListKeysetRequest{
			WfId:      workflowID,
			PageSize:  pageSize,
			PageToken: cursor,
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

		normalizedOrg := normalizeID(orgID)
		requestedProject := normalizeID(projectID)
		projectAccess := map[string]bool{}
		if requestedProject != "" {
			projectAccess[requestedProject] = true
		}

		pipelines := make([]pipelineSummary, 0, len(resp.GetPipelines()))
		for _, ppl := range resp.GetPipelines() {
			if ppl == nil {
				continue
			}

			summary := summarizePipeline(ppl)
			pipelineOrg := normalizeID(summary.OrganizationID)
			if pipelineOrg == "" || pipelineOrg != normalizedOrg {
				shared.ReportScopeMismatch(shared.ScopeMismatchMetadata{
					Tool:              listToolName,
					ResourceType:      "pipeline",
					ResourceID:        summary.ID,
					RequestOrgID:      orgID,
					ResourceOrgID:     summary.OrganizationID,
					RequestProjectID:  projectID,
					ResourceProjectID: summary.ProjectID,
				})
				return shared.ScopeMismatchError(listToolName, "organization"), nil
			}

			pipelineProject := normalizeID(summary.ProjectID)
			if pipelineProject == "" {
				shared.ReportScopeMismatch(shared.ScopeMismatchMetadata{
					Tool:              listToolName,
					ResourceType:      "pipeline",
					ResourceID:        summary.ID,
					RequestOrgID:      orgID,
					ResourceOrgID:     summary.OrganizationID,
					RequestProjectID:  projectID,
					ResourceProjectID: summary.ProjectID,
				})
				return shared.ScopeMismatchError(listToolName, "project"), nil
			}

			if requestedProject != "" && pipelineProject != requestedProject {
				shared.ReportScopeMismatch(shared.ScopeMismatchMetadata{
					Tool:              listToolName,
					ResourceType:      "pipeline",
					ResourceID:        summary.ID,
					RequestOrgID:      orgID,
					ResourceOrgID:     summary.OrganizationID,
					RequestProjectID:  projectID,
					ResourceProjectID: summary.ProjectID,
				})
				return shared.ScopeMismatchError(listToolName, "project"), nil
			}

			allowed, known := projectAccess[pipelineProject]
			if !known {
				err := authz.CheckProjectPermission(ctx, api, userID, orgID, summary.ProjectID, projectViewPermission)
				if err != nil {
					if errors.Is(err, authz.ErrPermissionDenied) {
						logging.ForComponent("tools").
							WithFields(logrus.Fields{
								"tool":       listToolName,
								"pipelineId": summary.ID,
								"workflowId": summary.WorkflowID,
								"projectId":  summary.ProjectID,
							}).
							Info("skipping pipeline due to missing project permission")
						projectAccess[pipelineProject] = false
						continue
					}
					return shared.ProjectAuthorizationError(err, orgID, summary.ProjectID, projectViewPermission), nil
				}
				projectAccess[pipelineProject] = true
				allowed = true
			}

			if !allowed {
				continue
			}

			pipelines = append(pipelines, summary)
		}

		result := listResult{Pipelines: pipelines}
		if token := strings.TrimSpace(resp.GetNextPageToken()); token != "" {
			result.NextCursor = token
		}

		markdown := formatPipelineListMarkdown(result, mode, workflowID, projectID, orgID, limit)
		markdown = shared.TruncateResponse(markdown, shared.MaxResponseChars)

		tracker.MarkSuccess()
		return &mcp.CallToolResult{
			Content: []mcp.Content{
				mcp.NewTextContent(markdown),
			},
			StructuredContent: result,
		}, nil
	}
}

func jobsHandler(api internalapi.Provider) server.ToolHandlerFunc {
	return func(ctx context.Context, req mcp.CallToolRequest) (*mcp.CallToolResult, error) {
		client := api.Pipelines()
		if client == nil {
			return mcp.NewToolResultError(errNoClient), nil
		}

		orgIDRaw, err := req.RequireString("organization_id")
		if err != nil {
			return mcp.NewToolResultError("organization_id is required. Use organizations_list to select an organization before listing jobs."), nil
		}
		orgID := strings.TrimSpace(orgIDRaw)
		if err := shared.ValidateUUID(orgID, "organization_id"); err != nil {
			return mcp.NewToolResultError(err.Error()), nil
		}

		tracker := shared.TrackToolExecution(ctx, jobsToolName, orgID)
		defer tracker.Cleanup()

		if err := shared.EnsureReadToolsFeature(ctx, api, orgID); err != nil {
			return mcp.NewToolResultError(err.Error()), nil
		}

		pipelineIDRaw, err := req.RequireString("pipeline_id")
		if err != nil {
			return mcp.NewToolResultError("pipeline_id is required. Provide the pipeline UUID from workflow_pipelines_list."), nil
		}
		pipelineID := strings.TrimSpace(pipelineIDRaw)
		if err := shared.ValidateUUID(pipelineID, "pipeline_id"); err != nil {
			return mcp.NewToolResultError(err.Error()), nil
		}

		userID := strings.ToLower(strings.TrimSpace(req.Header.Get("X-Semaphore-User-ID")))
		if err := shared.ValidateUUID(userID, "x-semaphore-user-id header"); err != nil {
			return mcp.NewToolResultError(fmt.Sprintf(`%v

The authentication layer must inject the X-Semaphore-User-ID header so we can verify project permissions before returning pipeline jobs.

Troubleshooting:
- Ensure requests pass through the authenticated proxy
- Verify the header value is a UUID (xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx)
- Retry once the header is present`, err)), nil
		}

		mode, err := shared.NormalizeMode(req.GetString("mode", "summary"))
		if err != nil {
			return mcp.NewToolResultError(fmt.Sprintf("Invalid mode parameter: %v", err)), nil
		}

		describeResp, err := clients.DescribePipeline(ctx, api, pipelineID, true)
		if err != nil {
			return mcp.NewToolResultError(err.Error()), nil
		}

		pipeline := summarizePipeline(describeResp.GetPipeline())
		if normalized := normalizeID(pipeline.OrganizationID); normalized == "" || normalized != normalizeID(orgID) {
			shared.ReportScopeMismatch(shared.ScopeMismatchMetadata{
				Tool:              jobsToolName,
				ResourceType:      "pipeline",
				ResourceID:        pipeline.ID,
				RequestOrgID:      orgID,
				ResourceOrgID:     pipeline.OrganizationID,
				RequestProjectID:  "",
				ResourceProjectID: pipeline.ProjectID,
			})
			return shared.ScopeMismatchError(jobsToolName, "organization"), nil
		}

		if strings.TrimSpace(pipeline.ProjectID) == "" {
			shared.ReportScopeMismatch(shared.ScopeMismatchMetadata{
				Tool:              jobsToolName,
				ResourceType:      "pipeline",
				ResourceID:        pipeline.ID,
				RequestOrgID:      orgID,
				ResourceOrgID:     pipeline.OrganizationID,
				RequestProjectID:  "",
				ResourceProjectID: pipeline.ProjectID,
			})
			return shared.ScopeMismatchError(jobsToolName, "project"), nil
		}

		if err := authz.CheckProjectPermission(ctx, api, userID, orgID, pipeline.ProjectID, projectViewPermission); err != nil {
			return shared.ProjectAuthorizationError(err, orgID, pipeline.ProjectID, projectViewPermission), nil
		}
		blocks := make([]blockJobGroup, 0, len(describeResp.GetBlocks()))
		jobs := make([]pipelineJobEntry, 0)
		for _, block := range describeResp.GetBlocks() {
			if block == nil {
				continue
			}
			group := blockJobGroup{
				ID:     block.GetBlockId(),
				Name:   strings.TrimSpace(block.GetName()),
				State:  blockStateToString(block.GetState()),
				Result: blockResultToString(block.GetResult()),
			}

			blockJobs := block.GetJobs()
			if len(blockJobs) > 0 {
				group.Jobs = make([]pipelineJobEntry, 0, len(blockJobs))
				for _, bj := range blockJobs {
					if bj == nil {
						continue
					}
					entry := pipelineJobEntry{
						JobID:     bj.GetJobId(),
						Name:      strings.TrimSpace(bj.GetName()),
						BlockID:   group.ID,
						BlockName: group.Name,
						Index:     bj.GetIndex(),
						Status:    strings.TrimSpace(bj.GetStatus()),
						Result:    strings.TrimSpace(bj.GetResult()),
					}
					group.Jobs = append(group.Jobs, entry)
					jobs = append(jobs, entry)
				}
			}

			blocks = append(blocks, group)
		}

		result := jobsListResult{
			Pipeline: pipeline,
			Blocks:   blocks,
			Jobs:     jobs,
			JobCount: len(jobs),
		}

		markdown := formatPipelineJobsMarkdown(result, mode, orgID)
		markdown = shared.TruncateResponse(markdown, shared.MaxResponseChars)

		tracker.MarkSuccess()
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
		ProjectID:      strings.TrimSpace(ppl.GetProjectId()),
		OrganizationID: strings.TrimSpace(ppl.GetOrganizationId()),
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

func normalizeID(value string) string {
	return strings.ToLower(strings.TrimSpace(value))
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
		mb.ListItem("Use workflows_search to confirm the workflow status.")
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
		if pipeline.CreatedAt != "" {
			mb.KeyValue("Created", pipeline.CreatedAt)
		}
		if pipeline.Branch != "" {
			mb.KeyValue("Branch", pipeline.Branch)
		}

		if mode == "detailed" {
			if pipeline.CommitSHA != "" {
				mb.KeyValue("Commit", shortenCommit(pipeline.CommitSHA))
			}
			if pipeline.Triggerer != "" {
				mb.KeyValue("Triggered By", titleCase(pipeline.Triggerer))
			}
			if pipeline.Queue.Name != "" {
				mb.KeyValue("Queue", fmt.Sprintf("%s (%s)", pipeline.Queue.Name, titleCase(pipeline.Queue.Type)))
			}
			if pipeline.RunningAt != "" {
				mb.KeyValue("Running Since", pipeline.RunningAt)
			}
			if pipeline.DoneAt != "" {
				mb.KeyValue("Completed", pipeline.DoneAt)
			}
			if pipeline.ErrorMessage != "" {
				mb.Paragraph(fmt.Sprintf("⚠️ **Error**: %s", pipeline.ErrorMessage))
			}
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

	}

	mb.Line()
	if result.NextCursor != "" {
		mb.Paragraph(fmt.Sprintf("📄 **More available**. Use `cursor=\"%s\"`", result.NextCursor))
	}

	return mb.String()
}

func formatPipelineJobsMarkdown(result jobsListResult, mode, orgID string) string {
	mb := shared.NewMarkdownBuilder()

	pipelineName := strings.TrimSpace(result.Pipeline.Name)
	if pipelineName == "" {
		pipelineName = result.Pipeline.ID
	}
	mb.H1(fmt.Sprintf("Jobs for Pipeline %s", pipelineName))
	mb.KeyValue("Pipeline ID", fmt.Sprintf("`%s`", result.Pipeline.ID))
	if result.Pipeline.State != "" {
		mb.KeyValue("Pipeline State", fmt.Sprintf("%s %s", shared.StatusIcon(result.Pipeline.State), titleCase(result.Pipeline.State)))
	}
	if result.Pipeline.Result != "" {
		res := titleCase(result.Pipeline.Result)
		if result.Pipeline.ResultReason != "" {
			res = fmt.Sprintf("%s (reason: %s)", res, titleCase(result.Pipeline.ResultReason))
		}
		mb.KeyValue("Pipeline Result", fmt.Sprintf("%s %s", shared.StatusIcon(result.Pipeline.Result), res))
	}
	mb.Paragraph(fmt.Sprintf("Organization: `%s` • Jobs discovered: %d", orgID, result.JobCount))

	if result.JobCount == 0 {
		mb.Paragraph("No jobs found for this pipeline. The pipeline may not have started yet or it may only include manual blocks.")
		return mb.String()
	}

	for idx, block := range result.Blocks {
		if idx > 0 {
			mb.Line()
		}

		title := block.Name
		if strings.TrimSpace(title) == "" {
			title = block.ID
		}
		mb.H2(fmt.Sprintf("Block %s", title))

		if mode == "detailed" {
			if block.State != "" {
				mb.KeyValue("State", fmt.Sprintf("%s %s", shared.StatusIcon(block.State), titleCase(block.State)))
			}
			if block.Result != "" {
				mb.KeyValue("Result", fmt.Sprintf("%s %s", shared.StatusIcon(block.Result), titleCase(block.Result)))
			}
		}

		if len(block.Jobs) == 0 {
			mb.Paragraph("No jobs reported for this block.")
			continue
		}

		for _, job := range block.Jobs {
			statusParts := []string{fmt.Sprintf("`%s`", job.JobID)}
			if job.Name != "" {
				statusParts = append(statusParts, fmt.Sprintf("%s", job.Name))
			}
			if mode == "detailed" {
				if job.Status != "" {
					statusParts = append(statusParts, fmt.Sprintf("status: %s %s", shared.StatusIcon(job.Status), titleCase(job.Status)))
				}
				if job.Result != "" {
					statusParts = append(statusParts, fmt.Sprintf("result: %s %s", shared.StatusIcon(job.Result), titleCase(job.Result)))
				}
				if job.Index > 0 {
					statusParts = append(statusParts, fmt.Sprintf("index %d", job.Index))
				}
				if job.Error != "" {
					statusParts = append(statusParts, fmt.Sprintf("error: %s", job.Error))
				}
			}
			mb.ListItem(strings.Join(statusParts, " • "))
		}
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
