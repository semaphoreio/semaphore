package projects

import (
	"context"
	"fmt"
	"sort"
	"strings"

	"github.com/google/uuid"
	"github.com/mark3labs/mcp-go/mcp"
	"github.com/mark3labs/mcp-go/server"
	projecthubpb "github.com/semaphoreio/semaphore/mcp_server/pkg/internal_api/projecthub"
	repoipb "github.com/semaphoreio/semaphore/mcp_server/pkg/internal_api/repository_integrator"
	"github.com/sirupsen/logrus"

	"github.com/semaphoreio/semaphore/mcp_server/pkg/authz"
	"github.com/semaphoreio/semaphore/mcp_server/pkg/internalapi"
	"github.com/semaphoreio/semaphore/mcp_server/pkg/logging"
	"github.com/semaphoreio/semaphore/mcp_server/pkg/tools/internal/shared"
	"github.com/semaphoreio/semaphore/mcp_server/pkg/utils"
)

const (
	listToolName       = "projects_list"
	searchToolName     = "projects_search"
	defaultListLimit   = 25
	maxListLimit       = 200
	defaultSearchLimit = 20
	defaultSearchPages = 5
	maxSearchPages     = 10
	searchPageSize     = 100

	orgViewPermission = "organization.view"
)

func listFullDescription() string {
	return `List projects that belong to a specific organization.

Use this when you need the project_id before digging into workflows, pipelines, or jobs.

Typical flows:
- "Show me projects in Acme Org" → call this tool, then ask follow-up questions
- "I only remember the repo URL" → list projects, then filter or use projects_search

Response modes:
- summary (default): project name, IDs, repository URL, visibility, last updated
- detailed: adds scheduler/task counts, custom permission flags, debug/attach permissions

Pagination:
- Default page size: 25 projects
- Maximum: 200 projects (be mindful of context size)
- Use cursor from previous response's nextCursor field to fetch more
- Empty/omitted cursor starts from the beginning

Examples:
1. List first 10 projects:
   projects_list(organization_id="aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee", limit=10)

2. Get detailed project info with schedulers:
   projects_list(organization_id="...", mode="detailed", limit=25)

3. Fetch next page of projects:
   projects_list(organization_id="...", cursor="opaque-token-from-previous-response", limit=25)

4. List many projects with full details:
   projects_list(organization_id="...", mode="detailed", limit=200)

Common follow-ups:
- projects_search(...) to find a specific repo or branch
- workflows_search(project_id="...", status="failed") to debug
`
}

func searchFullDescription() string {
	return `Search projects inside an organization by project name, repository URL, or description.

Use this to quickly narrow down a project when you only remember part of its name, repo slug, or default branch.

Ideal prompts:
- "Find the payments API project"
- "Which project uses repo github.com/example/mobile?"
- "Locate projects with 'infra' in the description"

Search details:
- Provide either a free-form query, a repository URL, or both
- Matches on project name, description, repository URL, repository name, and default branch
- Highlights matched fields and provides a confidence score (high / medium / low)

Tuning:
- limit: cap how many matches the LLM receives (default 20)
- max_pages: how many paginated fetches to inspect (default 5). Increase for large orgs.
- mode: 'summary' for concise answers, 'detailed' for schedulers/tasks/permissions

Examples:
1. Search by project name:
   projects_search(organization_id="...", query="mobile")

2. Search by repository URL:
   projects_search(organization_id="...", repository_url="github.com/example/app")

3. Combined search with increased depth:
   projects_search(organization_id="...", query="payments", max_pages=8, limit=30)

4. Detailed search results:
   projects_search(organization_id="...", query="backend", mode="detailed")

Follow-ups:
- Once you have a project_id, call workflows_search for deeper inspection.
`
}

// Register wires project tools into the MCP server.
func Register(s *server.MCPServer, api internalapi.Provider) {
	if s == nil {
		return
	}

	s.AddTool(newListTool(listToolName, listFullDescription()), listHandler(api))
	s.AddTool(newSearchTool(searchToolName, searchFullDescription()), searchHandler(api))
}

func newListTool(name, description string) mcp.Tool {
	return mcp.NewTool(
		name,
		mcp.WithDescription(description),
		mcp.WithString("organization_id",
			mcp.Required(),
			mcp.Description("Organization UUID whose projects should be listed. Format: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx."),
			mcp.Pattern(`^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$`),
		),
		mcp.WithString("cursor",
			mcp.Description("Opaque pagination token from a previous response's 'nextCursor' field. Omit or leave empty to start from the first page."),
		),
		mcp.WithNumber("limit",
			mcp.Description("Number of projects per page (1-200). Larger limits consume more context tokens."),
			mcp.Min(1),
			mcp.Max(maxListLimit),
			mcp.DefaultNumber(defaultListLimit),
		),
		mcp.WithString("mode",
			mcp.Description("Controls response detail. Use 'summary' for quick scans; 'detailed' adds schedulers, tasks, and permission metadata."),
			mcp.Enum("summary", "detailed"),
			mcp.DefaultString("summary"),
		),
		mcp.WithReadOnlyHintAnnotation(true),
		mcp.WithIdempotentHintAnnotation(true),
		mcp.WithOpenWorldHintAnnotation(true),
	)
}

func newSearchTool(name, description string) mcp.Tool {
	return mcp.NewTool(
		name,
		mcp.WithDescription(description),
		mcp.WithString("organization_id",
			mcp.Required(),
			mcp.Description("Organization UUID that scoping the search. Format: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx."),
			mcp.Pattern(`^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$`),
		),
		mcp.WithString("query",
			mcp.Description("Optional search query evaluated against project name, description, repository URL, repository name, and default branch."),
		),
		mcp.WithString("repository_url",
			mcp.Description("Optional repository URL to match (exact or substring, case-insensitive). Provide either this or query."),
		),
		mcp.WithNumber("limit",
			mcp.Description("Maximum number of matches to return (1-50)."),
			mcp.Min(1),
			mcp.Max(50),
			mcp.DefaultNumber(defaultSearchLimit),
		),
		mcp.WithNumber("max_pages",
			mcp.Description("Maximum number of paginated fetches to evaluate (1-10). Higher values explore more projects at the cost of latency."),
			mcp.Min(1),
			mcp.Max(maxSearchPages),
			mcp.DefaultNumber(defaultSearchPages),
		),
		mcp.WithString("mode",
			mcp.Description("Controls response detail. 'summary' shows key identifiers; 'detailed' adds schedulers/tasks/permissions metadata."),
			mcp.Enum("summary", "detailed"),
			mcp.DefaultString("summary"),
		),
		mcp.WithReadOnlyHintAnnotation(true),
		mcp.WithIdempotentHintAnnotation(true),
		mcp.WithOpenWorldHintAnnotation(true),
	)
}

type listResult struct {
	Projects   []projectSummary `json:"projects"`
	NextCursor string           `json:"nextCursor,omitempty"`
}

type searchResult struct {
	Projects      []projectSearchEntry `json:"projects"`
	TotalMatches  int                  `json:"totalMatches"`
	SearchedPages int                  `json:"searchedPages"`
	MoreAvailable bool                 `json:"moreAvailable"`
}

type projectSearchEntry struct {
	projectSummary
	MatchConfidence string   `json:"matchConfidence"`
	MatchedFields   []string `json:"matchedFields,omitempty"`
}

type projectSummary struct {
	ID          string            `json:"id"`
	Name        string            `json:"name"`
	Description string            `json:"description,omitempty"`
	Visibility  string            `json:"visibility,omitempty"`
	Repository  repositorySummary `json:"repository"`
	Details     *projectDetails   `json:"details,omitempty"`
}

type repositorySummary struct {
	URL            string `json:"url,omitempty"`
	Name           string `json:"name,omitempty"`
	DefaultBranch  string `json:"defaultBranch,omitempty"`
	PipelineFile   string `json:"pipelineFile,omitempty"`
	Integration    string `json:"integrationType,omitempty"`
	Public         bool   `json:"public"`
	Connected      bool   `json:"connected"`
	RepositoryID   string `json:"repositoryId,omitempty"`
	Owner          string `json:"owner,omitempty"`
	RunOnPresent   bool   `json:"runOnConfigured,omitempty"`
	IntegrationURL string `json:"integrationUrl,omitempty"`
}

type projectDetails struct {
	OrganizationID    string   `json:"organizationId,omitempty"`
	OwnerID           string   `json:"ownerId,omitempty"`
	CreatedAt         string   `json:"createdAt,omitempty"`
	CustomPermissions bool     `json:"customPermissions,omitempty"`
	SchedulerCount    int      `json:"schedulerCount,omitempty"`
	TaskCount         int      `json:"taskCount,omitempty"`
	DebugPermissions  []string `json:"debugPermissions,omitempty"`
	AttachPermissions []string `json:"attachPermissions,omitempty"`
}

func formatProjectListMarkdown(result listResult, mode string, orgID string) string {
	mb := shared.NewMarkdownBuilder()

	title := fmt.Sprintf("Projects in %s (%d)", orgID, len(result.Projects))
	mb.H1(title)

	if len(result.Projects) == 0 {
		mb.Paragraph("No projects found for this organization.")
		mb.Paragraph("**Tips:**")
		mb.ListItem("Confirm the organization_id is correct")
		mb.ListItem("Ensure the X-Semaphore-User-ID header identifies a user with access")
		mb.ListItem("Use projects_search for fuzzy matching")
		return mb.String()
	}

	for idx, project := range result.Projects {
		if idx > 0 {
			mb.Line()
		}

		displayName := project.Name
		if displayName == "" {
			displayName = "(unnamed project)"
		}
		mb.H2(displayName)

		mb.KeyValue("ID", fmt.Sprintf("`%s`", project.ID))

		if project.Repository.URL != "" {
			mb.KeyValue("Repository", project.Repository.URL)
		}

		// Status (minimal in summary mode)
		statusFlags := []string{}
		if project.Repository.Public {
			statusFlags = append(statusFlags, "🌐 Public")
		} else {
			statusFlags = append(statusFlags, "🔒 Private")
		}
		if len(statusFlags) > 0 {
			mb.KeyValue("Status", strings.Join(statusFlags, ", "))
		}

		// Detailed mode only
		if mode == "detailed" {
			if project.Description != "" {
				mb.Paragraph(project.Description)
			}

			if project.Repository.DefaultBranch != "" {
				mb.KeyValue("Default Branch", project.Repository.DefaultBranch)
			}
			if project.Repository.PipelineFile != "" {
				mb.KeyValue("Pipeline File", project.Repository.PipelineFile)
			}

			detailFlags := []string{}
			if project.Repository.Connected {
				detailFlags = append(detailFlags, "✅ Repo connected")
			} else {
				detailFlags = append(detailFlags, "⚠️ Repo not connected")
			}
			if project.Visibility != "" {
				detailFlags = append(detailFlags, fmt.Sprintf("Visibility: %s", project.Visibility))
			}
			if len(detailFlags) > 0 {
				mb.KeyValue("Details", strings.Join(detailFlags, ", "))
			}
		}

		if mode == "detailed" && project.Details != nil {
			mb.Newline()
			mb.H3("Details")
			if project.Details.OrganizationID != "" {
				mb.KeyValue("Organization ID", fmt.Sprintf("`%s`", project.Details.OrganizationID))
			}
			if project.Details.OwnerID != "" {
				mb.KeyValue("Owner ID", fmt.Sprintf("`%s`", project.Details.OwnerID))
			}
			if project.Details.CreatedAt != "" {
				mb.KeyValue("Created", project.Details.CreatedAt)
			}
			mb.KeyValue("Custom Permissions", shared.FormatBoolean(project.Details.CustomPermissions, "Yes", "No"))
			mb.KeyValue("Schedulers", fmt.Sprintf("%d", project.Details.SchedulerCount))
			mb.KeyValue("Tasks", fmt.Sprintf("%d", project.Details.TaskCount))
			if len(project.Details.DebugPermissions) > 0 {
				mb.KeyValue("Debug Permissions", strings.Join(project.Details.DebugPermissions, ", "))
			}
			if len(project.Details.AttachPermissions) > 0 {
				mb.KeyValue("Attach Permissions", strings.Join(project.Details.AttachPermissions, ", "))
			}
		}
	}

	mb.Line()
	mb.Paragraph(fmt.Sprintf("Showing %d projects", len(result.Projects)))

	if result.NextCursor != "" {
		mb.Paragraph(fmt.Sprintf("📄 **More projects available**. Use `cursor=\"%s\"` to fetch the next page.", result.NextCursor))
	}

	return mb.String()
}

func formatProjectSearchMarkdown(result searchResult, mode string, orgID string, query string, repoURL string, limit int, maxPages int) string {
	mb := shared.NewMarkdownBuilder()

	titleParts := []string{"Project Search Results"}
	if query != "" {
		titleParts = append(titleParts, fmt.Sprintf("query=\"%s\"", query))
	}
	if repoURL != "" {
		titleParts = append(titleParts, fmt.Sprintf("repository=\"%s\"", repoURL))
	}
	header := fmt.Sprintf("%s (%d returned)", strings.Join(titleParts, " • "), len(result.Projects))
	mb.H1(header)
	filters := []string{fmt.Sprintf("Organization: `%s`", orgID), fmt.Sprintf("Limit: %d", limit), fmt.Sprintf("Pages scanned: %d", result.SearchedPages)}
	mb.Paragraph(strings.Join(filters, " • "))

	if len(result.Projects) == 0 {
		mb.Paragraph("No projects matched the search criteria.")
		mb.Paragraph("**Suggestions:**")
		mb.ListItem("Try a different keyword (e.g., repository slug or branch name)")
		mb.ListItem("Increase `max_pages` to inspect more projects (up to 10)")
		mb.ListItem("Double-check the repository URL filter (use the canonical HTTPS URL)")
		return mb.String()
	}

	for idx, project := range result.Projects {
		if idx > 0 {
			mb.Line()
		}

		displayName := project.Name
		if displayName == "" {
			displayName = "(unnamed project)"
		}
		mb.H2(displayName)

		mb.KeyValue("Project ID", fmt.Sprintf("`%s`", project.ID))
		if project.Repository.URL != "" {
			mb.KeyValue("Repository", project.Repository.URL)
		}
		if project.Repository.DefaultBranch != "" {
			mb.KeyValue("Default Branch", project.Repository.DefaultBranch)
		}
		if project.Repository.Name != "" {
			mb.KeyValue("Repository Name", project.Repository.Name)
		}
		mb.KeyValue("Match Confidence", strings.Title(project.MatchConfidence))

		if len(project.MatchedFields) > 0 {
			mb.KeyValue("Matched Fields", formatMatchedFields(project.MatchedFields))
		}

		if mode == "detailed" && project.Details != nil {
			mb.Newline()
			mb.H3("Details")
			mb.KeyValue("Custom Permissions", shared.FormatBoolean(project.Details.CustomPermissions, "Yes", "No"))
			mb.KeyValue("Schedulers", fmt.Sprintf("%d", project.Details.SchedulerCount))
			mb.KeyValue("Tasks", fmt.Sprintf("%d", project.Details.TaskCount))
		}

	}

	mb.Line()
	mb.Paragraph(fmt.Sprintf("Total matches discovered: %d (showing up to %d).", result.TotalMatches, len(result.Projects)))
	if result.MoreAvailable {
		mb.Paragraph("🔍 **More matches likely exist.** Increase `max_pages` or adjust your query to retrieve additional projects.")
	}

	return mb.String()
}

func formatMatchedFields(fields []string) string {
	if len(fields) == 0 {
		return ""
	}

	labels := make([]string, 0, len(fields))
	for _, field := range fields {
		switch field {
		case "name_exact":
			labels = append(labels, "project name (exact)")
		case "name":
			labels = append(labels, "project name")
		case "description":
			labels = append(labels, "description")
		case "repository_url_exact":
			labels = append(labels, "repository URL (exact)")
		case "repository_url":
			labels = append(labels, "repository URL")
		case "repository_name":
			labels = append(labels, "repository name")
		case "default_branch":
			labels = append(labels, "default branch")
		default:
			labels = append(labels, field)
		}
	}

	return strings.Join(labels, ", ")
}

func listHandler(api internalapi.Provider) server.ToolHandlerFunc {
	return func(ctx context.Context, req mcp.CallToolRequest) (*mcp.CallToolResult, error) {
		client := api.Projects()
		if client == nil {
			return mcp.NewToolResultError(`Project gRPC endpoint is not configured.

This usually means:
1. INTERNAL_API_URL_PROJECT is missing or incorrect
2. The ProjectHub service is unreachable from the MCP server
3. Network connectivity problems

Verify server configuration and retry.`), nil
		}

		orgIDRaw, err := req.RequireString("organization_id")
		if err != nil {
			return mcp.NewToolResultError(`Missing required argument: organization_id.

Provide the organization UUID (format: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx).
You can discover organizations by calling organizations_list first.`), nil
		}
		orgID := strings.TrimSpace(orgIDRaw)
		if err := shared.ValidateUUID(orgID, "organization_id"); err != nil {
			return mcp.NewToolResultError(fmt.Sprintf(`%v

Example: projects_list(organization_id="aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee")`, err)), nil
		}

		if err := shared.EnsureReadToolsFeature(ctx, api, orgID); err != nil {
			return mcp.NewToolResultError(err.Error()), nil
		}

		mode, err := shared.NormalizeMode(req.GetString("mode", "summary"))
		if err != nil {
			return mcp.NewToolResultError(fmt.Sprintf(`Invalid mode parameter: %v

Use mode="summary" for quick scanning or mode="detailed" to include schedulers, tasks, and permission metadata.`, err)), nil
		}

		cursorRaw := req.GetString("cursor", "")
		cursor, err := shared.SanitizeCursorToken(cursorRaw, "cursor")
		if err != nil {
			return mcp.NewToolResultError(err.Error()), nil
		}

		limit := req.GetInt("limit", defaultListLimit)
		if limit <= 0 {
			limit = defaultListLimit
		} else if limit > maxListLimit {
			limit = maxListLimit
		}

		userID := strings.ToLower(strings.TrimSpace(req.Header.Get("X-Semaphore-User-ID")))
		if err := shared.ValidateUUID(userID, "x-semaphore-user-id header"); err != nil {
			return mcp.NewToolResultError(fmt.Sprintf(`%v

The authentication layer must inject the X-Semaphore-User-ID header so we can enforce per-user permissions.

Troubleshooting:
- Ensure calls pass through the authenticated proxy
- Verify the header value is a user UUID (xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx)
- Retry once the header is present`, err)), nil
		}

		pageSize, err := utils.IntToInt32(limit, "limit")
		if err != nil {
			return mcp.NewToolResultError(err.Error()), nil
		}

		if err := authz.CheckOrgPermission(ctx, api, userID, orgID, orgViewPermission); err != nil {
			return shared.OrgAuthorizationError(err, orgID, orgViewPermission), nil
		}

		request := &projecthubpb.ListKeysetRequest{
			Metadata:  projectRequestMeta(orgID, userID),
			PageToken: cursor,
			PageSize:  pageSize,
			Direction: projecthubpb.ListKeysetRequest_NEXT,
		}

		callCtx, cancel := context.WithTimeout(ctx, api.CallTimeout())
		defer cancel()

		resp, err := client.ListKeyset(callCtx, request)
		if err != nil {
			logging.ForComponent("rpc").
				WithFields(logrus.Fields{
					"rpc":            "project.ListKeyset",
					"organizationId": orgID,
					"cursor":         cursor,
					"limit":          limit,
					"mode":           mode,
					"userId":         userID,
				}).
				WithError(err).
				Error("project list RPC failed")
			return mcp.NewToolResultError(fmt.Sprintf(`Project list RPC failed: %v

Possible causes:
- Organization service is temporarily unavailable (retry shortly)
- Authentication token lacks access to this organization
- Network or routing issues

Suggested next steps:
- Verify organization_id is correct
- Confirm INTERNAL_API_URL_PROJECT points to a reachable endpoint
- Retry with a smaller limit`, err)), nil
		}

		if err := shared.CheckProjectResponseMeta(resp.GetMetadata()); err != nil {
			logging.ForComponent("rpc").
				WithField("rpc", "project.ListKeyset").
				WithError(err).
				Warn("project list returned non-OK status")
			return mcp.NewToolResultError(fmt.Sprintf(`Request failed: %v

This can happen if:
- organization_id is valid but you lack permission to list its projects
- The authenticated user (from X-Semaphore-User-ID) has no project access
- The organization has been suspended or deleted

Try removing optional filters or verifying access permissions.`, err)), nil
		}

		projects := make([]projectSummary, 0, len(resp.GetProjects()))
		for _, proj := range resp.GetProjects() {
			if proj == nil {
				continue
			}
			if mismatch := ensureProjectInOrg(listToolName, orgID, "", proj); mismatch != nil {
				return mismatch, nil
			}
			projects = append(projects, summarizeProject(proj, mode == "detailed"))
		}

		result := listResult{
			Projects:   projects,
			NextCursor: strings.TrimSpace(resp.GetNextPageToken()),
		}

		markdown := formatProjectListMarkdown(result, mode, orgID)
		markdown = shared.TruncateResponse(markdown, shared.MaxResponseChars)

		return &mcp.CallToolResult{
			Content: []mcp.Content{
				mcp.NewTextContent(markdown),
			},
			StructuredContent: result,
		}, nil
	}
}

func searchHandler(api internalapi.Provider) server.ToolHandlerFunc {
	return func(ctx context.Context, req mcp.CallToolRequest) (*mcp.CallToolResult, error) {
		client := api.Projects()
		if client == nil {
			return mcp.NewToolResultError(`Project gRPC endpoint is not configured.

Check INTERNAL_API_URL_PROJECT or MCP_PROJECT_GRPC_ENDPOINT and ensure ProjectHub is reachable.`), nil
		}

		orgIDRaw, err := req.RequireString("organization_id")
		if err != nil {
			return mcp.NewToolResultError(`Missing required argument: organization_id. Use organizations_list to discover organization IDs.`), nil
		}
		orgID := strings.TrimSpace(orgIDRaw)
		if err := shared.ValidateUUID(orgID, "organization_id"); err != nil {
			return mcp.NewToolResultError(err.Error()), nil
		}

		if err := shared.EnsureReadToolsFeature(ctx, api, orgID); err != nil {
			return mcp.NewToolResultError(err.Error()), nil
		}

		querySanitized, err := shared.SanitizeSearchQuery(req.GetString("query", ""), "query")
		if err != nil {
			return mcp.NewToolResultError(err.Error()), nil
		}
		queryDisplay := querySanitized
		queryNormalized := strings.ToLower(querySanitized)

		repoSanitized, err := shared.SanitizeRepositoryURLFilter(req.GetString("repository_url", ""), "repository_url")
		if err != nil {
			return mcp.NewToolResultError(err.Error()), nil
		}
		repoDisplay := repoSanitized
		repoFilter := strings.ToLower(repoSanitized)

		if queryNormalized == "" && repoFilter == "" {
			return mcp.NewToolResultError("Provide at least one of query or repository_url."), nil
		}

		mode, err := shared.NormalizeMode(req.GetString("mode", "summary"))
		if err != nil {
			return mcp.NewToolResultError(fmt.Sprintf("Invalid mode parameter: %v", err)), nil
		}

		limit := req.GetInt("limit", defaultSearchLimit)
		if limit <= 0 {
			limit = defaultSearchLimit
		} else if limit > 50 {
			limit = 50
		}

		maxPages := req.GetInt("max_pages", defaultSearchPages)
		if maxPages <= 0 {
			return mcp.NewToolResultError("max_pages must be at least 1. Increase it (maximum 10) to inspect more projects."), nil
		} else if maxPages > maxSearchPages {
			maxPages = maxSearchPages
		}

		userID := strings.ToLower(strings.TrimSpace(req.Header.Get("X-Semaphore-User-ID")))
		if err := shared.ValidateUUID(userID, "x-semaphore-user-id header"); err != nil {
			return mcp.NewToolResultError(fmt.Sprintf(`%v

The authentication layer must inject the X-Semaphore-User-ID header so we can enforce per-user permissions.

Troubleshooting:
- Ensure requests go through the authenticated proxy
- Verify the header contains a UUID (xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx)
- Retry once the header is present`, err)), nil
		}

		if err := authz.CheckOrgPermission(ctx, api, userID, orgID, orgViewPermission); err != nil {
			return shared.OrgAuthorizationError(err, orgID, orgViewPermission), nil
		}

		type candidate struct {
			summary       projectSummary
			score         int
			matchedFields []string
		}

		candidates := make([]candidate, 0, limit*2)
		totalMatches := 0
		searchedPages := 0
		moreAvailable := false

		for page := 1; page <= maxPages; page++ {
			pageNumber, err := utils.IntToInt32(page, "page")
			if err != nil {
				return mcp.NewToolResultError(err.Error()), nil
			}

			request := &projecthubpb.ListRequest{
				Metadata: projectRequestMeta(orgID, userID),
				Pagination: &projecthubpb.PaginationRequest{
					Page:     pageNumber,
					PageSize: searchPageSize,
				},
			}

			callCtx, cancel := context.WithTimeout(ctx, api.CallTimeout())
			resp, err := client.List(callCtx, request)
			cancel()
			if err != nil {
				logging.ForComponent("rpc").
					WithFields(logrus.Fields{
						"rpc":            "project.List",
						"organizationId": orgID,
						"page":           page,
						"mode":           mode,
						"query":          queryDisplay,
						"repositoryUrl":  repoDisplay,
						"userId":         userID,
					}).
					WithError(err).
					Error("project list RPC failed during search")
				return mcp.NewToolResultError(fmt.Sprintf(`Project search failed while fetching page %d: %v

Possible causes:
- High load on ProjectHub service (retry shortly)
- Network connectivity issues
- Organization ID is correct but service is unavailable

Try lowering max_pages or limit if the organization has many projects.`, page, err)), nil
			}

			if err := shared.CheckProjectResponseMeta(resp.GetMetadata()); err != nil {
				logging.ForComponent("rpc").
					WithField("rpc", "project.List").
					WithError(err).
					Warn("project search received non-OK status")
				return mcp.NewToolResultError(fmt.Sprintf(`Project search failed: %v

Ensure you have permission to list projects in organization %s.`, err, orgID)), nil
			}

			searchedPages++

			for _, proj := range resp.GetProjects() {
				if proj == nil {
					continue
				}
				if mismatch := ensureProjectInOrg(searchToolName, orgID, "", proj); mismatch != nil {
					return mismatch, nil
				}
				score := 0
				matched := []string{}

				if queryNormalized != "" {
					queryScore, queryMatches := scoreProjectMatch(proj, queryNormalized)
					score += queryScore
					matched = append(matched, queryMatches...)
				}

				if repoFilter != "" {
					spec := proj.GetSpec()
					var repoURL string
					if spec != nil && spec.GetRepository() != nil {
						repoURL = strings.ToLower(strings.TrimSpace(spec.GetRepository().GetUrl()))
					}
					if repoURL == "" {
						continue
					}
					if repoURL == repoFilter {
						score += 10
						matched = append(matched, "repository_url_exact")
					} else if strings.Contains(repoURL, repoFilter) {
						score += 6
						matched = append(matched, "repository_url")
					} else {
						continue
					}
				}

				if len(matched) == 0 {
					continue
				}

				totalMatches++
				candidates = append(candidates, candidate{
					summary:       summarizeProject(proj, mode == "detailed"),
					score:         score,
					matchedFields: matched,
				})
			}

			pagination := resp.GetPagination()
			if pagination == nil || int(pagination.GetPageNumber()) >= int(pagination.GetTotalPages()) {
				moreAvailable = false
				break
			}
			moreAvailable = true
		}

		if len(candidates) == 0 {
			result := searchResult{
				Projects:      []projectSearchEntry{},
				TotalMatches:  0,
				SearchedPages: searchedPages,
				MoreAvailable: moreAvailable,
			}

			markdown := formatProjectSearchMarkdown(result, mode, orgID, queryDisplay, repoDisplay, limit, maxPages)
			markdown = shared.TruncateResponse(markdown, shared.MaxResponseChars)

			return &mcp.CallToolResult{
				Content: []mcp.Content{
					mcp.NewTextContent(markdown),
				},
				StructuredContent: result,
			}, nil
		}

		sort.SliceStable(candidates, func(i, j int) bool {
			if candidates[i].score == candidates[j].score {
				return strings.Compare(candidates[i].summary.Name, candidates[j].summary.Name) < 0
			}
			return candidates[i].score > candidates[j].score
		})

		if len(candidates) > limit {
			candidates = candidates[:limit]
		}

		results := make([]projectSearchEntry, 0, len(candidates))
		for _, cand := range candidates {
			results = append(results, projectSearchEntry{
				projectSummary:  cand.summary,
				MatchConfidence: classifyConfidence(cand.score),
				MatchedFields:   cand.matchedFields,
			})
		}

		result := searchResult{
			Projects:      results,
			TotalMatches:  totalMatches,
			SearchedPages: searchedPages,
			MoreAvailable: moreAvailable || totalMatches > len(results),
		}

		markdown := formatProjectSearchMarkdown(result, mode, orgID, queryDisplay, repoDisplay, limit, maxPages)
		markdown = shared.TruncateResponse(markdown, shared.MaxResponseChars)

		return &mcp.CallToolResult{
			Content: []mcp.Content{
				mcp.NewTextContent(markdown),
			},
			StructuredContent: result,
		}, nil
	}
}

func projectRequestMeta(orgID, userID string) *projecthubpb.RequestMeta {
	return &projecthubpb.RequestMeta{
		ApiVersion: "v1alpha",
		Kind:       "Project",
		OrgId:      strings.TrimSpace(orgID),
		UserId:     strings.TrimSpace(userID),
		ReqId:      uuid.NewString(),
	}
}

func ensureProjectInOrg(tool, orgID, expectedProjectID string, project *projecthubpb.Project) *mcp.CallToolResult {
	if project == nil {
		return nil
	}
	meta := project.GetMetadata()
	if meta == nil {
		shared.ReportScopeMismatch(shared.ScopeMismatchMetadata{
			Tool:              tool,
			ResourceType:      "project",
			ResourceID:        "",
			RequestOrgID:      orgID,
			ResourceOrgID:     "",
			RequestProjectID:  expectedProjectID,
			ResourceProjectID: "",
		})
		return shared.ScopeMismatchError(tool, "organization")
	}
	resourceOrg := strings.TrimSpace(meta.GetOrgId())
	if !strings.EqualFold(resourceOrg, orgID) || resourceOrg == "" {
		shared.ReportScopeMismatch(shared.ScopeMismatchMetadata{
			Tool:              tool,
			ResourceType:      "project",
			ResourceID:        meta.GetId(),
			RequestOrgID:      orgID,
			ResourceOrgID:     resourceOrg,
			RequestProjectID:  expectedProjectID,
			ResourceProjectID: meta.GetId(),
		})
		return shared.ScopeMismatchError(tool, "organization")
	}
	return nil
}

func summarizeProject(project *projecthubpb.Project, includeDetails bool) projectSummary {
	if project == nil {
		return projectSummary{}
	}

	meta := project.GetMetadata()
	spec := project.GetSpec()
	var repoSummary repositorySummary
	if spec != nil {
		repoSummary = summarizeRepository(spec.GetRepository())
	}

	summary := projectSummary{
		ID:          meta.GetId(),
		Name:        meta.GetName(),
		Description: meta.GetDescription(),
		Visibility:  normalizeProjectVisibility(spec),
		Repository:  repoSummary,
	}

	if includeDetails {
		var debugPerms, attachPerms []string
		var schedulers, tasks int
		var customPerms bool
		if spec != nil {
			debugPerms = normalizePermissionTypes(spec.GetDebugPermissions())
			attachPerms = normalizePermissionTypes(spec.GetAttachPermissions())
			schedulers = len(spec.GetSchedulers())
			tasks = len(spec.GetTasks())
			customPerms = spec.GetCustomPermissions()
		}
		details := projectDetails{
			OrganizationID:    meta.GetOrgId(),
			OwnerID:           meta.GetOwnerId(),
			CreatedAt:         shared.FormatTimestamp(meta.GetCreatedAt()),
			CustomPermissions: customPerms,
			SchedulerCount:    schedulers,
			TaskCount:         tasks,
			DebugPermissions:  debugPerms,
			AttachPermissions: attachPerms,
		}
		summary.Details = &details
	}

	return summary
}

func summarizeRepository(repo *projecthubpb.Project_Spec_Repository) repositorySummary {
	if repo == nil {
		return repositorySummary{}
	}

	return repositorySummary{
		URL:           repo.GetUrl(),
		Name:          repo.GetName(),
		Owner:         repo.GetOwner(),
		DefaultBranch: repo.GetDefaultBranch(),
		PipelineFile:  repo.GetPipelineFile(),
		Integration:   normalizeIntegration(repo.GetIntegrationType()),
		Public:        repo.GetPublic(),
		Connected:     repo.GetConnected(),
		RepositoryID:  repo.GetId(),
		RunOnPresent:  repo.GetRunPresent() != nil,
	}
}

func normalizeProjectVisibility(spec *projecthubpb.Project_Spec) string {
	if spec == nil {
		return ""
	}
	value := spec.GetVisibility().String()
	return normalizeEnumName(value, "Project_Spec_")
}

func normalizeIntegration(integration repoipb.IntegrationType) string {
	return normalizeEnumName(integration.String(), "IntegrationType_")
}

func normalizePermissionTypes(perms []projecthubpb.Project_Spec_PermissionType) []string {
	if len(perms) == 0 {
		return nil
	}
	out := make([]string, 0, len(perms))
	for _, p := range perms {
		out = append(out, normalizeEnumName(p.String(), "Project_Spec_"))
	}
	return out
}

func normalizeEnumName(raw, prefix string) string {
	raw = strings.TrimSpace(raw)
	if raw == "" {
		return ""
	}
	if strings.HasPrefix(raw, prefix) {
		raw = strings.TrimPrefix(raw, prefix)
	}
	raw = strings.ReplaceAll(raw, "_", " ")
	return strings.ToLower(raw)
}

func scoreProjectMatch(project *projecthubpb.Project, query string) (int, []string) {
	if project == nil {
		return 0, nil
	}
	metadata := project.GetMetadata()
	spec := project.GetSpec()
	var repo *projecthubpb.Project_Spec_Repository
	if spec != nil {
		repo = spec.GetRepository()
	}

	score := 0
	var matched []string

	name := strings.ToLower(strings.TrimSpace(metadata.GetName()))
	description := strings.ToLower(strings.TrimSpace(metadata.GetDescription()))
	repoURL := ""
	repoName := ""
	defaultBranch := ""
	if repo != nil {
		repoURL = strings.ToLower(strings.TrimSpace(repo.GetUrl()))
		repoName = strings.ToLower(strings.TrimSpace(repo.GetName()))
		defaultBranch = strings.ToLower(strings.TrimSpace(repo.GetDefaultBranch()))
	}

	if name == query {
		score += 6
		matched = append(matched, "name_exact")
	} else if strings.Contains(name, query) {
		score += 4
		matched = append(matched, "name")
	}

	if desc := description; desc != "" && strings.Contains(desc, query) {
		score += 2
		matched = append(matched, "description")
	}

	if repoURL != "" && strings.Contains(repoURL, query) {
		score += 3
		matched = append(matched, "repository_url")
	}

	if repoName != "" && strings.Contains(repoName, query) {
		score += 2
		matched = append(matched, "repository_name")
	}

	if defaultBranch != "" && strings.Contains(defaultBranch, query) {
		score++
		matched = append(matched, "default_branch")
	}

	return score, matched
}

func classifyConfidence(score int) string {
	switch {
	case score >= 6:
		return "high"
	case score >= 3:
		return "medium"
	default:
		return "low"
	}
}
