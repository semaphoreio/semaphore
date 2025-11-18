package workflows

import (
	"context"
	"fmt"
	"regexp"
	"sort"
	"strconv"
	"strings"
	"unicode/utf8"

	"github.com/google/uuid"
	"github.com/mark3labs/mcp-go/mcp"
	"github.com/mark3labs/mcp-go/server"
	"github.com/sirupsen/logrus"

	"github.com/semaphoreio/semaphore/mcp_server/pkg/authz"
	workflowpb "github.com/semaphoreio/semaphore/mcp_server/pkg/internal_api/plumber_w_f.workflow"
	projecthubpb "github.com/semaphoreio/semaphore/mcp_server/pkg/internal_api/projecthub"
	repopb "github.com/semaphoreio/semaphore/mcp_server/pkg/internal_api/repository_integrator"
	userpb "github.com/semaphoreio/semaphore/mcp_server/pkg/internal_api/user"
	"github.com/semaphoreio/semaphore/mcp_server/pkg/internalapi"
	"github.com/semaphoreio/semaphore/mcp_server/pkg/logging"
	"github.com/semaphoreio/semaphore/mcp_server/pkg/tools/internal/shared"
	"github.com/semaphoreio/semaphore/mcp_server/pkg/utils"
)

const (
	searchToolName        = "workflows_search"
	runToolName           = "workflows_run"
	defaultLimit          = 20
	maxLimit              = 100
	missingWorkflowError  = "workflow gRPC endpoint is not configured"
	projectViewPermission = "project.view"
	projectRunPermission  = "project.job.rerun"
	defaultPipelineFile   = ".semaphore/semaphore.yml"
)

func searchFullDescription() string {
	return `Search recent workflows for a project (most recent first).

Use this when you need to answer:
- "Show the last N workflows for project X"
- "List failed workflows on the main branch"
- "Who triggered the latest deployment workflow?"

- organization_id: identify which organization’s project you are querying (required)
- project_id: identify which project to search workflows for (required)
- branch: limit results to a specific branch (e.g., "main" or "release/*")
- requester: filter by a specific requester (UUID, username, or automation handle)
- my_workflows_only: when true (default), limit results to workflows triggered by the authenticated user
- cursor: paginate through older results using the previous response's nextCursor
- limit: number of workflows to return (default 20, max 100)

Response modes:
- summary (default): workflow ID, branch, triggered by, commit SHA, created time
- detailed: adds pipeline IDs, rerun metadata, and repository IDs

Examples:
1. List recent workflows for a project:
   workflows_search(project_id="...", organization_id="...", limit=10)

2. Find failed workflows on main branch:
   workflows_search(project_id="...", organization_id="...", branch="main", mode="detailed")

3. Search workflows by automation requester:
   workflows_search(project_id="...", organization_id="...", requester="deploy-bot", my_workflows_only=false)

4. Paginate through older workflows:
   workflows_search(project_id="...", organization_id="...", cursor="opaque-token-from-previous-call")

Next steps:
- Call jobs_logs(job_id="...") after identifying failing jobs
- Use workflows_search(project_id="...", branch="main") regularly to monitor your own workflows`
}

func runFullDescription() string {
	return `Schedule a new workflow run for a project.

Use this when you need to:
- Kick off a pipeline with a specific branch, tag, or commit
- Trigger a workflow with custom parameters without using the UI

Required inputs:
- organization_id: Organization UUID that owns the project
- project_id: Project UUID where the workflow should run
- reference: Git reference (branch, tag, or pull request), e.g. "refs/heads/main", "refs/tags/v1.0", or "refs/pull/42"

Optional inputs:
- commit_sha: Pin the run to a specific commit
- pipeline_file: Override the pipeline definition path (defaults to the project's configured file)
- parameters: A key/value map of parameters to expose as environment variables (values convert to strings)

The authenticated user must have permissions to run workflows in the specified project.`
}

// Register wires the workflows tool into the MCP server.
func Register(s *server.MCPServer, api internalapi.Provider) {
	s.AddTool(newTool(searchToolName, searchFullDescription()), listHandler(api))
	s.AddTool(newRunTool(runToolName, runFullDescription()), runHandler(api))
}

func newTool(name, description string) mcp.Tool {
	return mcp.NewTool(
		name,
		mcp.WithDescription(description),
		mcp.WithString("project_id",
			mcp.Required(),
			mcp.Description("Project UUID that scopes the workflow search. Format: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx."),
			mcp.Pattern(`^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$`),
		),
		mcp.WithString("organization_id",
			mcp.Required(),
			mcp.Description("Organization UUID associated with the project. Keep this consistent across subsequent tool calls."),
			mcp.Pattern(`^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$`),
		),
		mcp.WithString("branch",
			mcp.Description("Optional branch filter. Supports exact matches (e.g., \"main\")."),
		),
		mcp.WithString("requester",
			mcp.Description("Optional requester identifier (UUID, username, or automation handle) to filter workflows."),
		),
		mcp.WithBoolean("my_workflows_only",
			mcp.Description("When true (default), only return workflows triggered by the authenticated user."),
			func(schema map[string]any) { schema["default"] = true },
		),
		mcp.WithString("cursor",
			mcp.Description("Pagination token from a prior call's nextCursor. Use to fetch older workflows."),
		),
		mcp.WithNumber("limit",
			mcp.Description("Number of workflows to return (1-100). Defaults to 20."),
			mcp.Min(1),
			mcp.Max(maxLimit),
			mcp.DefaultNumber(defaultLimit),
		),
		mcp.WithString("mode",
			mcp.Description("Response detail. Use 'summary' for compact output; 'detailed' adds pipeline IDs and rerun metadata."),
			mcp.Enum("summary", "detailed"),
			mcp.DefaultString("summary"),
		),
		mcp.WithReadOnlyHintAnnotation(true),
		mcp.WithIdempotentHintAnnotation(true),
		mcp.WithOpenWorldHintAnnotation(true),
	)
}

func newRunTool(name, description string) mcp.Tool {
	return mcp.NewTool(
		name,
		mcp.WithDescription(description),
		mcp.WithString(
			"project_id",
			mcp.Required(),
			mcp.Description("Project UUID where the workflow should run."),
			mcp.Pattern(`^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$`),
		),
		mcp.WithString(
			"organization_id",
			mcp.Required(),
			mcp.Description("Organization UUID that owns the project."),
			mcp.Pattern(`^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$`),
		),
		mcp.WithString(
			"reference",
			mcp.Required(),
			mcp.Description("Git reference to run (branch, tag, or pull request, refs/... pattern)."),
		),
		mcp.WithString(
			"commit_sha",
			mcp.Description("Optional commit SHA to pin the workflow run."),
		),
		mcp.WithString(
			"pipeline_file",
			mcp.Description("Optional pipeline definition YAML file path within the repository."),
		),
		mcp.WithObject(
			"parameters",
			mcp.Description("Optional key/value parameters exposed as environment variables."),
			mcp.AdditionalProperties(map[string]any{
				"oneOf": []any{
					map[string]any{"type": "string"},
					map[string]any{"type": "number"},
					map[string]any{"type": "boolean"},
					map[string]any{"type": "null"},
				},
			}),
		),
		mcp.WithIdempotentHintAnnotation(false),
	)
}

type summary struct {
	ID              string `json:"id"`
	InitialPipeline string `json:"initialPipelineId,omitempty"`
	ProjectID       string `json:"projectId,omitempty"`
	OrganizationID  string `json:"organizationId,omitempty"`
	Branch          string `json:"branch,omitempty"`
	CommitSHA       string `json:"commitSha,omitempty"`
	RequesterID     string `json:"requesterId,omitempty"`
	TriggeredBy     string `json:"triggeredBy,omitempty"`
	CreatedAt       string `json:"createdAt,omitempty"`
	RerunOf         string `json:"rerunOf,omitempty"`
	RepositoryID    string `json:"repositoryId,omitempty"`
}

type listResult struct {
	Workflows  []summary `json:"workflows"`
	NextCursor string    `json:"nextCursor,omitempty"`
}

type runResult struct {
	WorkflowID   string `json:"workflowId"`
	PipelineID   string `json:"pipelineId"`
	Reference    string `json:"reference"`
	CommitSHA    string `json:"commitSha,omitempty"`
	PipelineFile string `json:"pipelineFile"`
}

func listHandler(api internalapi.Provider) server.ToolHandlerFunc {
	return func(ctx context.Context, req mcp.CallToolRequest) (*mcp.CallToolResult, error) {
		client := api.Workflow()
		if client == nil {
			return mcp.NewToolResultError(missingWorkflowError), nil
		}

		projectIDRaw, err := req.RequireString("project_id")
		if err != nil {
			return mcp.NewToolResultError(`Missing required argument: project_id. Provide the project UUID (xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx).`), nil
		}
		projectID := strings.TrimSpace(projectIDRaw)
		if err := shared.ValidateUUID(projectID, "project_id"); err != nil {
			return mcp.NewToolResultError(err.Error()), nil
		}

		orgIDRaw, err := req.RequireString("organization_id")
		if err != nil {
			return mcp.NewToolResultError(`Missing required argument: organization_id. Provide the organization UUID returned by organizations_list.`), nil
		}
		orgID := strings.TrimSpace(orgIDRaw)
		if err := shared.ValidateUUID(orgID, "organization_id"); err != nil {
			return mcp.NewToolResultError(err.Error()), nil
		}

		tracker := shared.TrackToolExecution(ctx, searchToolName, orgID)
		defer tracker.Cleanup()

		if err := shared.EnsureReadToolsFeature(ctx, api, orgID); err != nil {
			return mcp.NewToolResultError(err.Error()), nil
		}

		mode, err := shared.NormalizeMode(req.GetString("mode", "summary"))
		if err != nil {
			return mcp.NewToolResultError(fmt.Sprintf("Invalid mode parameter: %v", err)), nil
		}

		branch, err := shared.SanitizeBranch(req.GetString("branch", ""), "branch")
		if err != nil {
			return mcp.NewToolResultError(err.Error()), nil
		}
		requesterFilter, err := shared.SanitizeRequesterFilter(req.GetString("requester", ""), "requester")
		if err != nil {
			return mcp.NewToolResultError(err.Error()), nil
		}
		myWorkflowsOnly := mcp.ParseBoolean(req, "my_workflows_only", true)
		cursor, err := shared.SanitizeCursorToken(req.GetString("cursor", ""), "cursor")
		if err != nil {
			return mcp.NewToolResultError(err.Error()), nil
		}

		userID := strings.ToLower(strings.TrimSpace(req.Header.Get("X-Semaphore-User-ID")))
		if err := shared.ValidateUUID(userID, "x-semaphore-user-id header"); err != nil {
			return mcp.NewToolResultError(fmt.Sprintf(`%v

The authentication layer must inject the X-Semaphore-User-ID header so we can scope workflow searches to the authenticated caller.

Troubleshooting:
- Ensure requests pass through the auth proxy
- Verify the header value is a UUID (xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx)
- Retry once the header is present`, err)), nil
		}

		if err := authz.CheckProjectPermission(ctx, api, userID, orgID, projectID, projectViewPermission); err != nil {
			return shared.ProjectAuthorizationError(err, orgID, projectID, projectViewPermission), nil
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

		request := &workflowpb.ListKeysetRequest{
			ProjectId: projectID,
			PageSize:  pageSize,
			PageToken: cursor,
			Order:     workflowpb.ListKeysetRequest_BY_CREATION_TIME_DESC,
			Direction: workflowpb.ListKeysetRequest_NEXT,
		}

		request.OrganizationId = orgID
		if branch != "" {
			request.BranchName = branch
		}
		var effectiveRequester string
		if requesterFilter != "" {
			resolved, err := resolveRequesterID(ctx, api, requesterFilter)
			if err != nil {
				return mcp.NewToolResultError(err.Error()), nil
			}
			effectiveRequester = resolved
		} else if myWorkflowsOnly {
			effectiveRequester = userID
		}

		if effectiveRequester != "" {
			request.RequesterId = effectiveRequester
		}

		callCtx, cancel := context.WithTimeout(ctx, api.CallTimeout())
		defer cancel()

		effectiveRequester = request.GetRequesterId()
		resp, err := client.ListKeyset(callCtx, request)
		if err != nil {
			logging.ForComponent("rpc").
				WithFields(logrus.Fields{
					"rpc":        "workflow.ListKeyset",
					"projectId":  projectID,
					"limit":      limit,
					"cursor":     cursor,
					"branch":     branch,
					"userId":     userID,
					"requester":  effectiveRequester,
					"scoped":     myWorkflowsOnly,
					"mode":       mode,
					"hasOrgId":   orgID != "",
					"legacyTool": false,
				}).
				WithError(err).
				Error("workflow list RPC failed")
			return mcp.NewToolResultError(fmt.Sprintf(`Workflow list RPC failed: %v

Possible causes:
- Project does not exist or you lack access rights
- Internal workflow service is unavailable (retry shortly)
- Network connectivity issues between MCP server and workflow service

Try reducing the limit or removing filters to see if results return.`, err)), nil
		}

		if err := shared.CheckStatus(resp.GetStatus()); err != nil {
			logging.ForComponent("rpc").
				WithFields(logrus.Fields{
					"rpc":       "workflow.ListKeyset",
					"projectId": projectID,
				}).
				WithError(err).
				Warn("workflow list returned non-OK status")
			return mcp.NewToolResultError(fmt.Sprintf(`Request failed: %v

Double-check that:
- project_id is correct
- You have permission to view workflows for this project
- The organization is active and not suspended`, err)), nil
		}

		expectedOrg := normalizeID(orgID)
		expectedProject := normalizeID(projectID)
		workflows := make([]summary, 0, len(resp.GetWorkflows()))
		for _, wf := range resp.GetWorkflows() {
			if wf == nil {
				continue
			}

			workflowOrg := normalizeID(wf.GetOrganizationId())
			if workflowOrg == "" || workflowOrg != expectedOrg {
				shared.ReportScopeMismatch(shared.ScopeMismatchMetadata{
					Tool:              searchToolName,
					ResourceType:      "workflow",
					ResourceID:        wf.GetWfId(),
					RequestOrgID:      orgID,
					ResourceOrgID:     wf.GetOrganizationId(),
					RequestProjectID:  projectID,
					ResourceProjectID: wf.GetProjectId(),
				})
				return shared.ScopeMismatchError(searchToolName, "organization"), nil
			}

			workflowProject := normalizeID(wf.GetProjectId())
			if workflowProject == "" || workflowProject != expectedProject {
				shared.ReportScopeMismatch(shared.ScopeMismatchMetadata{
					Tool:              searchToolName,
					ResourceType:      "workflow",
					ResourceID:        wf.GetWfId(),
					RequestOrgID:      orgID,
					ResourceOrgID:     wf.GetOrganizationId(),
					RequestProjectID:  projectID,
					ResourceProjectID: wf.GetProjectId(),
				})
				return shared.ScopeMismatchError(searchToolName, "project"), nil
			}

			workflows = append(workflows, summary{
				ID:              wf.GetWfId(),
				InitialPipeline: wf.GetInitialPplId(),
				ProjectID:       strings.TrimSpace(wf.GetProjectId()),
				OrganizationID:  strings.TrimSpace(wf.GetOrganizationId()),
				Branch:          wf.GetBranchName(),
				CommitSHA:       wf.GetCommitSha(),
				RequesterID:     wf.GetRequesterId(),
				TriggeredBy:     triggeredByToString(wf.GetTriggeredBy()),
				CreatedAt:       shared.FormatTimestamp(wf.GetCreatedAt()),
				RerunOf:         wf.GetRerunOf(),
				RepositoryID:    wf.GetRepositoryId(),
			})
		}

		result := listResult{Workflows: workflows}
		if token := strings.TrimSpace(resp.GetNextPageToken()); token != "" {
			result.NextCursor = token
		}

		markdown := formatWorkflowsMarkdown(result, mode, projectID, orgID, branch, requesterFilter, myWorkflowsOnly, userID, limit)
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

func runHandler(api internalapi.Provider) server.ToolHandlerFunc {
	return func(ctx context.Context, req mcp.CallToolRequest) (*mcp.CallToolResult, error) {
		orgIDRaw, err := req.RequireString("organization_id")
		if err != nil {
			return mcp.NewToolResultError(`Missing required argument: organization_id. Provide the organization UUID returned by organizations_list.`), nil
		}
		orgID := strings.TrimSpace(orgIDRaw)
		if err := shared.ValidateUUID(orgID, "organization_id"); err != nil {
			return mcp.NewToolResultError(err.Error()), nil
		}

		if err := shared.EnsureWriteToolsFeature(ctx, api, orgID); err != nil {
			return mcp.NewToolResultError(err.Error()), nil
		}

		tracker := shared.TrackToolExecution(ctx, runToolName, orgID)
		defer tracker.Cleanup()

		workflowClient := api.Workflow()
		if workflowClient == nil {
			return mcp.NewToolResultError(missingWorkflowError), nil
		}
		projectClient := api.Projects()
		if projectClient == nil {
			return mcp.NewToolResultError("project gRPC endpoint is not configured"), nil
		}

		projectIDRaw, err := req.RequireString("project_id")
		if err != nil {
			return mcp.NewToolResultError(`Missing required argument: project_id. Provide the project UUID (xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx).`), nil
		}
		projectID := strings.TrimSpace(projectIDRaw)
		if err := shared.ValidateUUID(projectID, "project_id"); err != nil {
			return mcp.NewToolResultError(err.Error()), nil
		}

		userID := strings.ToLower(strings.TrimSpace(req.Header.Get("X-Semaphore-User-ID")))
		if err := shared.ValidateUUID(userID, "x-semaphore-user-id header"); err != nil {
			return mcp.NewToolResultError(fmt.Sprintf(`%v

The authentication layer must inject the X-Semaphore-User-ID header so we can authorize workflow runs.`, err)), nil
		}

		if err := authz.CheckProjectPermission(ctx, api, userID, orgID, projectID, projectRunPermission); err != nil {
			return shared.ProjectAuthorizationError(err, orgID, projectID, projectRunPermission), nil
		}

		referenceRaw, err := req.RequireString("reference")
		if err != nil {
			return mcp.NewToolResultError(`Missing required argument: reference. Provide the branch or git ref to run.`), nil
		}
		reference, err := sanitizeGitReference(referenceRaw, "reference")
		if err != nil {
			return mcp.NewToolResultError(err.Error()), nil
		}

		commitSHA := strings.TrimSpace(req.GetString("commit_sha", ""))
		if err := validateCommitSHA(commitSHA, "commit_sha"); err != nil {
			return mcp.NewToolResultError(err.Error()), nil
		}

		pipelineFileInput := strings.TrimSpace(req.GetString("pipeline_file", ""))
		if err := validatePipelineFile(pipelineFileInput, "pipeline_file"); err != nil {
			return mcp.NewToolResultError(err.Error()), nil
		}

		parameters, err := extractParameters(req.GetArguments()["parameters"])
		if err != nil {
			return mcp.NewToolResultError(err.Error()), nil
		}

		describeReq := projectDescribeRequest(projectID, orgID, userID)
		callCtx, cancel := context.WithTimeout(ctx, api.CallTimeout())
		defer cancel()

		describeResp, err := projectClient.Describe(callCtx, describeReq)
		if err != nil {
			logging.ForComponent("rpc").
				WithFields(logrus.Fields{
					"rpc":       "project.Describe",
					"projectId": projectID,
					"orgId":     orgID,
				}).
				WithError(err).
				Error("project describe RPC failed")
			return mcp.NewToolResultError("Unable to load project details. Please confirm the project exists and retry."), nil
		}

		project, err := validateProjectDescribeResponse(describeResp, orgID, projectID)
		if err != nil {
			return mcp.NewToolResultError(err.Error()), nil
		}

		spec := project.GetSpec()
		if spec == nil {
			return mcp.NewToolResultError("Project specification is missing. Please try again once the project is fully initialized."), nil
		}

		repo := spec.GetRepository()
		if repo == nil {
			return mcp.NewToolResultError("Project repository configuration is missing. Configure the repository before scheduling workflows."), nil
		}

		pipelineFile := pipelineFileInput
		if pipelineFile == "" {
			pipelineFile = strings.TrimSpace(repo.GetPipelineFile())
			if pipelineFile == "" {
				pipelineFile = defaultPipelineFile
			}
		}
		if err := validatePipelineFile(pipelineFile, "pipeline_file"); err != nil {
			return mcp.NewToolResultError(err.Error()), nil
		}

		envVars, err := buildEnvVars(parameters)
		if err != nil {
			return mcp.NewToolResultError(err.Error()), nil
		}

		requestToken := uuid.NewString()
		branchName := branchNameFromReference(reference)
		label := labelFromReference(reference)
		gitReference := ensureGitReference(reference)

		serviceType, err := mapIntegrationType(repo.GetIntegrationType())
		if err != nil {
			logging.ForComponent("workflows").
				WithFields(logrus.Fields{
					"projectId":       projectID,
					"orgId":           orgID,
					"integrationType": repo.GetIntegrationType(),
				}).
				WithError(err).
				Error("unsupported repository integration type")
			return mcp.NewToolResultError("Project repository integration type is not supported. Please contact support."), nil
		}

		scheduleReq := &workflowpb.ScheduleRequest{
			ProjectId:             projectID,
			OrganizationId:        orgID,
			RequesterId:           userID,
			DefinitionFile:        pipelineFile,
			RequestToken:          requestToken,
			GitReference:          gitReference,
			Label:                 label,
			TriggeredBy:           workflowpb.TriggeredBy_API,
			StartInConceivedState: true,
			Service:               serviceType,
			EnvVars:               envVars,
			Repo: &workflowpb.ScheduleRequest_Repo{
				Owner:        strings.TrimSpace(repo.GetOwner()),
				RepoName:     strings.TrimSpace(repo.GetName()),
				BranchName:   branchName,
				CommitSha:    commitSHA,
				RepositoryId: strings.TrimSpace(repo.GetId()),
			},
		}
		scheduleCtx, cancelSchedule := context.WithTimeout(ctx, api.CallTimeout())
		defer cancelSchedule()

		scheduleResp, err := workflowClient.Schedule(scheduleCtx, scheduleReq)
		if err != nil {
			logging.ForComponent("rpc").
				WithFields(logrus.Fields{
					"rpc":       "workflow.Schedule",
					"projectId": projectID,
					"orgId":     orgID,
					"reference": reference,
				}).
				WithError(err).
				Error("workflow schedule RPC failed")
			return mcp.NewToolResultError("Workflow schedule failed. Verify the repository settings and try again."), nil
		}

		if err := shared.CheckStatus(scheduleResp.GetStatus()); err != nil {
			return mcp.NewToolResultError(fmt.Sprintf("Workflow schedule failed: %v", err)), nil
		}

		result := runResult{
			WorkflowID:   strings.TrimSpace(scheduleResp.GetWfId()),
			PipelineID:   strings.TrimSpace(scheduleResp.GetPplId()),
			Reference:    gitReference,
			CommitSHA:    commitSHA,
			PipelineFile: pipelineFile,
		}

		markdown := formatRunMarkdown(result)
		markdown = shared.TruncateResponse(markdown, shared.MaxResponseChars)

		tracker.MarkSuccess()
		return &mcp.CallToolResult{
			Content:           []mcp.Content{mcp.NewTextContent(markdown)},
			StructuredContent: result,
		}, nil
	}
}

func formatWorkflowsMarkdown(result listResult, mode, projectID, orgID, branch, requester string, myWorkflowsOnly bool, userID string, limit int) string {
	mb := shared.NewMarkdownBuilder()

	header := fmt.Sprintf("Workflows (%d returned)", len(result.Workflows))
	mb.H1(header)

	if len(result.Workflows) == 0 {
		mb.Paragraph("No workflows matched the current filters.")
		mb.Paragraph("**Suggestions:**")
		mb.ListItem("Remove the branch filter to broaden the search")
		mb.ListItem("Verify the project_id is correct and has recent activity")
		mb.ListItem("Confirm the authenticated user has permission to view this project")
		return mb.String()
	}

	for idx, wf := range result.Workflows {
		if idx > 0 {
			mb.Line()
		}

		mb.H2(fmt.Sprintf("Workflow %s", wf.ID))

		if wf.CreatedAt != "" {
			mb.KeyValue("Created", wf.CreatedAt)
		}
		if wf.Branch != "" {
			mb.KeyValue("Branch", wf.Branch)
		}
		mb.KeyValue("Triggered By", humanizeTriggeredBy(wf.TriggeredBy))

		if mode == "detailed" {
			if wf.RequesterID != "" {
				mb.KeyValue("Requester", fmt.Sprintf("`%s`", wf.RequesterID))
			}
			if wf.CommitSHA != "" {
				mb.KeyValue("Commit", shortenCommit(wf.CommitSHA))
			}
			if wf.InitialPipeline != "" {
				mb.KeyValue("Initial Pipeline", fmt.Sprintf("`%s`", wf.InitialPipeline))
			}
			if wf.RepositoryID != "" {
				mb.KeyValue("Repository", fmt.Sprintf("`%s`", wf.RepositoryID))
			}
			if wf.RerunOf != "" {
				mb.KeyValue("Rerun Of", fmt.Sprintf("`%s`", wf.RerunOf))
			}
			if wf.ProjectID != "" {
				mb.KeyValue("Project ID", fmt.Sprintf("`%s`", wf.ProjectID))
			}
			if wf.OrganizationID != "" {
				mb.KeyValue("Organization ID", fmt.Sprintf("`%s`", wf.OrganizationID))
			}
		}
	}

	mb.Line()
	if result.NextCursor != "" {
		mb.Paragraph(fmt.Sprintf("📄 **More available**. Use `cursor=\"%s\"`", result.NextCursor))
	}

	return mb.String()
}

func humanizeTriggeredBy(value string) string {
	value = strings.TrimSpace(value)
	if value == "" {
		return "Unspecified"
	}
	parts := strings.Split(value, "_")
	for i, part := range parts {
		if part == "" {
			continue
		}
		part = strings.ToLower(part)
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

func normalizeID(value string) string {
	return strings.ToLower(strings.TrimSpace(value))
}

func resolveRequesterID(ctx context.Context, api internalapi.Provider, raw string) (string, error) {
	candidate := strings.ToLower(strings.TrimSpace(raw))
	if candidate == "" {
		return "", fmt.Errorf("requester must not be empty")
	}

	if err := shared.ValidateUUID(candidate, "requester"); err == nil {
		return candidate, nil
	}

	client := api.Users()
	if client == nil {
		return "", fmt.Errorf(`Unable to resolve requester %q: user service is not configured. Provide a user UUID or configure INTERNAL_API_URL_USER.`, raw)
	}

	req := &userpb.DescribeByRepositoryProviderRequest{
		Provider: &userpb.RepositoryProvider{
			Type:  userpb.RepositoryProvider_GITHUB,
			Scope: userpb.RepositoryProvider_PUBLIC,
			Login: candidate,
		},
	}

	callCtx, cancel := context.WithTimeout(ctx, api.CallTimeout())
	defer cancel()

	resp, err := client.DescribeByRepositoryProvider(callCtx, req)
	if err != nil {
		logging.ForComponent("rpc").
			WithField("rpc", "user.DescribeByRepositoryProvider").
			WithField("login", candidate).
			WithError(err).
			Warn("user lookup by repository provider failed")
		return "", fmt.Errorf(`Failed to resolve requester %q via GitHub handle: %v`, raw, err)
	}

	userID := strings.ToLower(strings.TrimSpace(resp.GetId()))
	if userID == "" {
		return "", fmt.Errorf(`Failed to resolve requester %q: no matching user found.`, raw)
	}

	return userID, nil
}

func triggeredByToString(value workflowpb.TriggeredBy) string {
	if name, ok := workflowpb.TriggeredBy_name[int32(value)]; ok {
		return strings.ToLower(name)
	}
	return "unspecified"
}

var (
	commitPattern    = regexp.MustCompile(`^[0-9a-f]{7,64}$`)
	parameterPattern = regexp.MustCompile(`^[A-Za-z_][A-Za-z0-9_]*$`)
)

func sanitizeGitReference(raw, field string) (string, error) {
	value := strings.TrimSpace(raw)
	if value == "" {
		return "", fmt.Errorf("%s is required", field)
	}
	return shared.SanitizeBranch(value, field)
}

func validateCommitSHA(value, field string) error {
	value = strings.TrimSpace(value)
	if value == "" {
		return nil
	}
	if len(value) > 64 {
		return fmt.Errorf("%s must not exceed 64 characters", field)
	}
	if !commitPattern.MatchString(strings.ToLower(value)) {
		return fmt.Errorf("%s must be a hexadecimal SHA (7-64 characters)", field)
	}
	return nil
}

func validatePipelineFile(value, field string) error {
	value = strings.TrimSpace(value)
	if value == "" {
		return nil
	}
	length := utf8.RuneCountInString(value)
	if length > 512 {
		return fmt.Errorf("%s must not exceed 512 characters", field)
	}
	for _, r := range value {
		if r < 32 || r == 127 {
			return fmt.Errorf("%s contains control characters", field)
		}
		if r == '\\' {
			return fmt.Errorf("%s must not contain backslashes", field)
		}
	}
	if strings.Contains(value, "..") {
		return fmt.Errorf("%s must not contain '..' sequences", field)
	}
	if strings.HasPrefix(value, "/") {
		return fmt.Errorf("%s must be a relative path", field)
	}
	return nil
}

func extractParameters(raw any) (map[string]any, error) {
	if raw == nil {
		return nil, nil
	}
	params, ok := raw.(map[string]any)
	if !ok {
		return nil, fmt.Errorf("parameters must be a key/value map with string keys")
	}
	return params, nil
}

func buildEnvVars(params map[string]any) ([]*workflowpb.ScheduleRequest_EnvVar, error) {
	if len(params) == 0 {
		return nil, nil
	}
	names := make([]string, 0, len(params))
	for name := range params {
		names = append(names, name)
	}
	sort.Strings(names)
	result := make([]*workflowpb.ScheduleRequest_EnvVar, 0, len(names))
	for _, name := range names {
		clean := strings.TrimSpace(name)
		if clean == "" {
			return nil, fmt.Errorf("parameter names must not be empty")
		}
		if err := validateParameterName(clean); err != nil {
			return nil, err
		}
		value, err := parameterValueToString(params[name])
		if err != nil {
			return nil, err
		}
		result = append(result, &workflowpb.ScheduleRequest_EnvVar{Name: clean, Value: value})
	}
	return result, nil
}

func validateParameterName(name string) error {
	if utf8.RuneCountInString(name) > 128 {
		return fmt.Errorf("parameter names must not exceed 128 characters")
	}
	for _, r := range name {
		if r < 32 || r == 127 {
			return fmt.Errorf("parameter %q contains control characters", name)
		}
	}
	if !parameterPattern.MatchString(name) {
		return fmt.Errorf("parameter %q must start with a letter or underscore, followed by letters, digits, or underscores", name)
	}
	return nil
}

func parameterValueToString(value any) (string, error) {
	switch v := value.(type) {
	case nil:
		return "", nil
	case string:
		return v, nil
	case bool:
		if v {
			return "true", nil
		}
		return "false", nil
	case float64:
		return strconv.FormatFloat(v, 'f', -1, 64), nil
	case int:
		return strconv.Itoa(v), nil
	case int32:
		return strconv.FormatInt(int64(v), 10), nil
	case int64:
		return strconv.FormatInt(v, 10), nil
	case uint32:
		return strconv.FormatUint(uint64(v), 10), nil
	case uint64:
		return strconv.FormatUint(v, 10), nil
	default:
		return "", fmt.Errorf("parameters values must be strings, numbers, booleans, or null")
	}
}

func projectDescribeRequest(projectID, orgID, userID string) *projecthubpb.DescribeRequest {
	return &projecthubpb.DescribeRequest{
		Id: projectID,
		Metadata: &projecthubpb.RequestMeta{
			ApiVersion: "v1alpha",
			Kind:       "Project",
			OrgId:      strings.TrimSpace(orgID),
			UserId:     strings.TrimSpace(userID),
			ReqId:      uuid.NewString(),
		},
	}
}

func validateProjectDescribeResponse(resp *projecthubpb.DescribeResponse, orgID, projectID string) (*projecthubpb.Project, error) {
	if resp == nil {
		return nil, fmt.Errorf("Project describe returned no data")
	}
	meta := resp.GetMetadata()
	if meta == nil || meta.GetStatus() == nil {
		return nil, fmt.Errorf("Project describe response is missing status information")
	}
	if meta.GetStatus().GetCode() != projecthubpb.ResponseMeta_OK {
		message := strings.TrimSpace(meta.GetStatus().GetMessage())
		if message == "" {
			message = "Project describe request failed"
		}
		return nil, fmt.Errorf("%s", message)
	}
	project := resp.GetProject()
	if project == nil {
		return nil, fmt.Errorf("Project describe response did not include project details")
	}
	projMeta := project.GetMetadata()
	if projMeta == nil {
		return nil, fmt.Errorf("Project metadata is missing")
	}
	if resourceOrg := strings.TrimSpace(projMeta.GetOrgId()); resourceOrg == "" || !strings.EqualFold(resourceOrg, orgID) {
		shared.ReportScopeMismatch(shared.ScopeMismatchMetadata{
			Tool:              runToolName,
			ResourceType:      "project",
			ResourceID:        projMeta.GetId(),
			RequestOrgID:      orgID,
			ResourceOrgID:     resourceOrg,
			RequestProjectID:  projectID,
			ResourceProjectID: projMeta.GetId(),
		})
		return nil, fmt.Errorf("Project %s does not belong to organization %s", projectID, orgID)
	}
	return project, nil
}

// branchNameFromReference extracts the branch name from a git reference.
// Note: Tags intentionally return the full "refs/tags/*" path as required by the workflow service API.
func branchNameFromReference(ref string) string {
	value := strings.TrimSpace(ref)
	switch {
	case strings.HasPrefix(value, "refs/heads/"):
		return strings.TrimPrefix(value, "refs/heads/")
	case strings.HasPrefix(value, "refs/tags/"):
		return value // Workflow service expects full path for tags
	case strings.HasPrefix(value, "refs/pull/"):
		return "pull-request-" + strings.TrimPrefix(value, "refs/pull/")
	default:
		return value
	}
}

func labelFromReference(ref string) string {
	value := strings.TrimSpace(ref)
	switch {
	case strings.HasPrefix(value, "refs/tags/"):
		return strings.TrimPrefix(value, "refs/tags/")
	case strings.HasPrefix(value, "refs/pull/"):
		return strings.TrimPrefix(value, "refs/pull/")
	case strings.HasPrefix(value, "refs/heads/"):
		return strings.TrimPrefix(value, "refs/heads/")
	default:
		return value
	}
}

func ensureGitReference(ref string) string {
	ref = strings.TrimSpace(ref)
	if strings.HasPrefix(ref, "refs/") {
		return ref
	}
	return "refs/heads/" + ref
}

func mapIntegrationType(integration repopb.IntegrationType) (workflowpb.ScheduleRequest_ServiceType, error) {
	switch integration {
	case repopb.IntegrationType_GITHUB_OAUTH_TOKEN:
		return workflowpb.ScheduleRequest_GIT_HUB, nil
	case repopb.IntegrationType_GITHUB_APP:
		return workflowpb.ScheduleRequest_GIT_HUB, nil
	case repopb.IntegrationType_BITBUCKET:
		return workflowpb.ScheduleRequest_BITBUCKET, nil
	case repopb.IntegrationType_GITLAB:
		return workflowpb.ScheduleRequest_GITLAB, nil
	case repopb.IntegrationType_GIT:
		return workflowpb.ScheduleRequest_GIT, nil
	default:
		return workflowpb.ScheduleRequest_GIT_HUB, fmt.Errorf("unsupported repository integration type: %v", integration)
	}
}

func formatRunMarkdown(result runResult) string {
	mb := shared.NewMarkdownBuilder()
	mb.H1("Workflow Scheduled")
	if result.WorkflowID != "" {
		mb.KeyValue("Workflow ID", fmt.Sprintf("`%s`", result.WorkflowID))
	}
	if result.PipelineID != "" {
		mb.KeyValue("Initial Pipeline", fmt.Sprintf("`%s`", result.PipelineID))
	}
	if result.Reference != "" {
		mb.KeyValue("Reference", result.Reference)
	}
	if result.CommitSHA != "" {
		mb.KeyValue("Commit", shortenCommit(result.CommitSHA))
	}
	if result.PipelineFile != "" {
		mb.KeyValue("Pipeline File", result.PipelineFile)
	}
	return mb.String()
}
