package organizations

import (
	"context"
	"fmt"
	"strings"

	"github.com/mark3labs/mcp-go/mcp"
	"github.com/mark3labs/mcp-go/server"
	orgpb "github.com/semaphoreio/semaphore/mcp_server/pkg/internal_api/organization"
	"github.com/sirupsen/logrus"

	"github.com/semaphoreio/semaphore/mcp_server/pkg/internalapi"
	"github.com/semaphoreio/semaphore/mcp_server/pkg/logging"
	"github.com/semaphoreio/semaphore/mcp_server/pkg/tools/internal/shared"
)

const (
	listToolName    = "organizations_list"
	defaultPageSize = 20
	maxPageSize     = 100
)

func fullDescription() string {
	return `List organizations available to the authenticated user.

This tool retrieves all organizations the user can access. The caller's user ID is derived from the X-Semaphore-User-ID header that the authentication layer injects into every request, so no additional arguments are required to identify the caller.

Use this as the first step when users ask questions like:
- "Show me my organizations"
- "Which orgs can I access?"
- "List all my projects" (first get orgs, then list projects)

Response Modes:
- summary (default): Name, ID, username, creation date, verification status
- detailed: Includes IP allowlists, identity provider settings, workflow restrictions, and all organization settings

Pagination:
- Default page size: 20 organizations
- Maximum page size: 100 organizations
- Use 'cursor' from the previous response's 'nextCursor' field to fetch the next page
- Empty/omitted cursor starts from the beginning

Common Usage Patterns:
1. List all accessible orgs → Pick one → Call projects_list(organization_id="...")
2. List orgs → Filter by name in application code → Use selected org_id

Examples:
1. List first 10 organizations:
   organizations_list(limit=10, mode="summary")

2. Paginate through all organizations:
   organizations_list(cursor="opaque-cursor-from-previous-response", limit=50)

3. Get detailed org information with IP allowlists:
   organizations_list(mode="detailed", limit=5)

4. Fetch specific page of organizations:
   organizations_list(limit=20, cursor="next-page-token")

Common Errors:
- Empty list: User may not belong to any organizations (check authentication)
- RPC failed: Organization service temporarily unavailable (retry after a few seconds)
- Missing header: Ensure the authentication proxy forwards X-Semaphore-User-ID

Next Steps After This Call:
- Store the organization_id you intend to use (for example in a local ".semaphore/org" file) so future requests can reference it quickly
- Use projects_list(organization_id="...") to see projects in an organization
- Use projects_search(organization_id="...", query="...") to find specific projects
`
}

// Register wires organization tools into the MCP server.
func Register(s *server.MCPServer, api internalapi.Provider) {
	if s == nil {
		return
	}
	s.AddTool(newListTool(listToolName, fullDescription()), listHandler(api))
}

func newListTool(name, description string) mcp.Tool {
	return mcp.NewTool(
		name,
		mcp.WithDescription(description),

		mcp.WithString("cursor",
			mcp.Description("Opaque pagination token from a previous response's 'nextCursor' field. Omit or leave empty to start from the first page."),
		),
		mcp.WithNumber("limit",
			mcp.Description("Number of organizations to return per page (1-100). Higher values consume more tokens but require fewer API calls. Default: 20."),
			mcp.Min(1),
			mcp.Max(maxPageSize),
			mcp.DefaultNumber(defaultPageSize),
		),
		mcp.WithString("mode",
			mcp.Description("Response detail level. Use 'summary' for quick listings; use 'detailed' only when you need IP allowlists, identity providers, or specific organization settings."),
			mcp.Enum("summary", "detailed"),
			mcp.DefaultString("summary"),
		),
		mcp.WithReadOnlyHintAnnotation(true),
		mcp.WithIdempotentHintAnnotation(true),
		mcp.WithOpenWorldHintAnnotation(true),
	)
}

type listResult struct {
	Organizations []organizationSummary `json:"organizations"`
	NextCursor    string                `json:"nextCursor,omitempty"`
}

type organizationSummary struct {
	ID          string               `json:"id"`
	Name        string               `json:"name"`
	Username    string               `json:"username,omitempty"`
	OwnerID     string               `json:"ownerId,omitempty"`
	CreatedAt   string               `json:"createdAt,omitempty"`
	Verified    bool                 `json:"verified,omitempty"`
	Restricted  bool                 `json:"restricted,omitempty"`
	Suspended   bool                 `json:"suspended,omitempty"`
	OpenSource  bool                 `json:"openSource,omitempty"`
	Details     *organizationDetails `json:"details,omitempty"`
	RawSettings map[string]string    `json:"settings,omitempty"`
}

type organizationDetails struct {
	AllowedIDProviders     []string `json:"allowedIdProviders,omitempty"`
	IPAllowList            []string `json:"ipAllowList,omitempty"`
	DenyMemberWorkflows    bool     `json:"denyMemberWorkflows,omitempty"`
	DenyNonMemberWorkflows bool     `json:"denyNonMemberWorkflows,omitempty"`
}

func listHandler(api internalapi.Provider) server.ToolHandlerFunc {
	return func(ctx context.Context, req mcp.CallToolRequest) (*mcp.CallToolResult, error) {
		client := api.Organizations()
		if client == nil {
			return mcp.NewToolResultError(`Organization gRPC endpoint is not configured.

This usually means:
1. The INTERNAL_API_URL_ORGANIZATION environment variable is not set
2. The organization service is not accessible from this server
3. Network connectivity issues

Please check the server configuration and retry.`), nil
		}

		// Validate and normalize mode
		mode, err := shared.NormalizeMode(req.GetString("mode", "summary"))
		if err != nil {
			return mcp.NewToolResultError(fmt.Sprintf(`Invalid mode parameter: %v

The 'mode' parameter must be either 'summary' or 'detailed':
- summary: Returns basic org information (name, ID, status)
- detailed: Returns full details including IP allowlists, settings, permissions

Example: semaphore_organizations_list(mode="summary")`, err)), nil
		}

		// Fetch and validate the caller's user ID from the authentication header
		userID := strings.ToLower(strings.TrimSpace(req.Header.Get("X-Semaphore-User-ID")))
		if err := shared.ValidateUUID(userID, "x-semaphore-user-id header"); err != nil {
			return mcp.NewToolResultError(fmt.Sprintf(`%v

The authentication layer must inject the X-Semaphore-User-ID header so the tool knows which user's organizations to list.

Troubleshooting:
- Ensure requests pass through the authentication proxy
- Verify the header value is the caller's UUID (format: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx)
- Retry once the header is present

Example: semaphore_organizations_list(limit=20)`, err)), nil
		}

		limit := req.GetInt("limit", defaultPageSize)
		if limit <= 0 {
			limit = defaultPageSize
		} else if limit > maxPageSize {
			limit = maxPageSize
		}

		request := &orgpb.ListRequest{
			UserId:    userID,
			PageSize:  int32(limit),
			PageToken: strings.TrimSpace(req.GetString("cursor", "")),
			Order:     orgpb.ListRequest_BY_NAME_ASC,
		}

		callCtx, cancel := context.WithTimeout(ctx, api.CallTimeout())
		defer cancel()

		resp, err := client.List(callCtx, request)
		if err != nil {
			logging.ForComponent("rpc").
				WithFields(logrus.Fields{
					"rpc":     "organization.List",
					"userId":  userID,
					"limit":   limit,
					"cursor":  request.GetPageToken(),
					"mode":    mode,
					"reqName": listToolName,
				}).
				WithError(err).
				Error("organization list RPC failed")

			return mcp.NewToolResultError(fmt.Sprintf(`Organization list RPC failed: %v

This usually means:
1. The organization service is temporarily unavailable (retry in a few seconds)
2. Network connectivity issues between MCP server and internal APIs
3. Invalid authentication credentials

Suggested next steps:
- Retry the request after a short delay
- Check server logs for more details
- Verify the organization service is running and accessible`, err)), nil
		}

		if err := shared.CheckResponseStatus(resp.GetStatus()); err != nil {
			logging.ForComponent("rpc").
				WithField("rpc", "organization.List").
				WithError(err).
				Warn("organization list returned non-OK status")

			return mcp.NewToolResultError(fmt.Sprintf(`Request failed: %v

This may indicate:
- The X-Semaphore-User-ID header references a user you cannot access
- Authentication token expired or invalid
- Internal service error

Try:
- Confirming the X-Semaphore-User-ID header is present and valid
- Verifying authentication credentials
- Checking if you have permission to list organizations`, err)), nil
		}

		includeDetails := mode == "detailed"
		orgs := make([]organizationSummary, 0, len(resp.GetOrganizations()))
		for _, o := range resp.GetOrganizations() {
			orgs = append(orgs, summarizeOrganization(o, includeDetails))
		}

		result := listResult{
			Organizations: orgs,
			NextCursor:    strings.TrimSpace(resp.GetNextPageToken()),
		}

		// Generate Markdown summary
		markdown := formatOrganizationsMarkdown(orgs, mode, result.NextCursor)
		markdown = shared.TruncateResponse(markdown, shared.MaxResponseChars)

		return &mcp.CallToolResult{
			Content: []mcp.Content{
				mcp.NewTextContent(markdown),
			},
			StructuredContent: result,
		}, nil
	}
}

func formatOrganizationsMarkdown(orgs []organizationSummary, mode string, nextCursor string) string {
	mb := shared.NewMarkdownBuilder()

	mb.H1(fmt.Sprintf("Organizations (%d)", len(orgs)))

	if len(orgs) == 0 {
		mb.Paragraph("No organizations found. The authenticated user may not belong to any organizations, or their account currently has no access.")
		mb.Paragraph("**Troubleshooting:**")
		mb.ListItem("Verify authentication credentials are valid")
		mb.ListItem("Check if the user account is active")
		mb.ListItem("Confirm the X-Semaphore-User-ID header is present and points to the expected user")
		return mb.String()
	}

	for i, org := range orgs {
		if i > 0 {
			mb.Newline()
		}

		mb.H2(fmt.Sprintf("%s `%s`", org.Name, org.Username))

		mb.KeyValue("ID", fmt.Sprintf("`%s`", org.ID))

		if mode == "detailed" {
			mb.KeyValue("Owner ID", fmt.Sprintf("`%s`", org.OwnerID))
			if org.CreatedAt != "" {
				mb.KeyValue("Created", org.CreatedAt)
			}
		}

		// Status flags
		statusItems := []string{}
		if org.Verified {
			statusItems = append(statusItems, "✅ Verified")
		}
		if org.Suspended {
			statusItems = append(statusItems, "⛔ Suspended")
		}
		if org.Restricted {
			statusItems = append(statusItems, "🔒 Restricted")
		}
		if org.OpenSource {
			statusItems = append(statusItems, "🌐 Open Source")
		}
		if len(statusItems) > 0 {
			mb.KeyValue("Status", strings.Join(statusItems, ", "))
		}

		// Detailed mode information
		if mode == "detailed" && org.Details != nil {
			mb.Newline()
			mb.H3("Details")

			if len(org.Details.IPAllowList) > 0 {
				mb.KeyValue("IP Allow List", fmt.Sprintf("%d entries", len(org.Details.IPAllowList)))
				for _, ip := range org.Details.IPAllowList {
					mb.ListItem(fmt.Sprintf("  - `%s`", ip))
				}
			}

			if len(org.Details.AllowedIDProviders) > 0 {
				mb.KeyValue("Allowed Identity Providers", strings.Join(org.Details.AllowedIDProviders, ", "))
			}

			if org.Details.DenyMemberWorkflows {
				mb.ListItem("⚠️ Member workflows are denied")
			}
			if org.Details.DenyNonMemberWorkflows {
				mb.ListItem("⚠️ Non-member workflows are denied")
			}

			if len(org.RawSettings) > 0 {
				mb.H3("Settings")
				for key, value := range org.RawSettings {
					mb.KeyValue(key, value)
				}
			}
		}
	}

	// Pagination hint
	if nextCursor != "" {
		mb.Line()
		mb.Paragraph(fmt.Sprintf("📄 **More organizations available**. Use `cursor=\"%s\"` to fetch the next page.", nextCursor))
	}

	return mb.String()
}

func summarizeOrganization(org *orgpb.Organization, detailed bool) organizationSummary {
	if org == nil {
		return organizationSummary{}
	}

	summary := organizationSummary{
		ID:         org.GetOrgId(),
		Name:       org.GetName(),
		Username:   org.GetOrgUsername(),
		OwnerID:    org.GetOwnerId(),
		CreatedAt:  shared.FormatTimestamp(org.GetCreatedAt()),
		Verified:   org.GetVerified(),
		Restricted: org.GetRestricted(),
		Suspended:  org.GetSuspended(),
		OpenSource: org.GetOpenSource(),
	}

	if detailed {
		summary.Details = &organizationDetails{
			AllowedIDProviders:     append([]string{}, org.GetAllowedIdProviders()...),
			IPAllowList:            append([]string{}, org.GetIpAllowList()...),
			DenyMemberWorkflows:    org.GetDenyMemberWorkflows(),
			DenyNonMemberWorkflows: org.GetDenyNonMemberWorkflows(),
		}

		settings := make(map[string]string, len(org.GetSettings()))
		for _, setting := range org.GetSettings() {
			if setting == nil {
				continue
			}
			settings[strings.TrimSpace(setting.GetKey())] = strings.TrimSpace(setting.GetValue())
		}
		if len(settings) > 0 {
			summary.RawSettings = settings
		}
	}

	return summary
}
