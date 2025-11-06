package workflows

import (
	"context"
	"fmt"
	"strings"

	"github.com/mark3labs/mcp-go/mcp"
	"github.com/mark3labs/mcp-go/server"
	"github.com/sirupsen/logrus"

	"github.com/semaphoreio/semaphore/mcp_server/pkg/authz"
	workflowpb "github.com/semaphoreio/semaphore/mcp_server/pkg/internal_api/plumber_w_f.workflow"
	userpb "github.com/semaphoreio/semaphore/mcp_server/pkg/internal_api/user"
	"github.com/semaphoreio/semaphore/mcp_server/pkg/internalapi"
	"github.com/semaphoreio/semaphore/mcp_server/pkg/logging"
	"github.com/semaphoreio/semaphore/mcp_server/pkg/tools/internal/shared"
	"github.com/semaphoreio/semaphore/mcp_server/pkg/utils"
)

const (
	searchToolName        = "workflows_search"
	defaultLimit          = 20
	maxLimit              = 100
	missingWorkflowError  = "workflow gRPC endpoint is not configured"
	projectViewPermission = "project.view"
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

// Register wires the workflows tool into the MCP server.
func Register(s *server.MCPServer, api internalapi.Provider) {
	s.AddTool(newTool(searchToolName, searchFullDescription()), listHandler(api))
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

		return &mcp.CallToolResult{
			Content: []mcp.Content{
				mcp.NewTextContent(markdown),
			},
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
