package organizations

import (
	"context"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"sort"
	"strconv"
	"strings"
	"time"

	"github.com/mark3labs/mcp-go/mcp"
	"github.com/mark3labs/mcp-go/server"
	orgpb "github.com/semaphoreio/semaphore/mcp_server/pkg/internal_api/organization"
	rbacpb "github.com/semaphoreio/semaphore/mcp_server/pkg/internal_api/rbac"
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

This tool retrieves all organizations the user can access. 

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

		rbacClient := api.RBAC()
		if rbacClient == nil {
			return mcp.NewToolResultError(`RBAC gRPC endpoint is not configured.

This usually means:
1. The INTERNAL_API_URL_RBAC environment variable is not set
2. The RBAC service is not accessible from this server
3. Network connectivity issues

The RBAC service determines which organizations the authenticated user can access. Please configure the endpoint and retry.`), nil
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

		cursor, err := shared.SanitizeCursorToken(req.GetString("cursor", ""), "cursor")
		if err != nil {
			return mcp.NewToolResultError(fmt.Sprintf(`Invalid cursor parameter: %v

The 'cursor' parameter must be the opaque value returned in a previous response's 'nextCursor' field.

Tips:
- Omit the cursor to start from the beginning
- Use exactly the value returned from 'nextCursor' without modification`, err)), nil
		}

		offset, err := parseCursorOffset(cursor)
		if err != nil {
			return mcp.NewToolResultError(fmt.Sprintf(`Invalid cursor parameter: %v

The 'cursor' parameter must be the opaque value returned in a previous response's 'nextCursor' field.

Tips:
- Omit the cursor to start from the beginning
- Use exactly the value returned from 'nextCursor' without modification`, err)), nil
		}

		accessibleIDs, err := listAccessibleOrgIDs(ctx, rbacClient, api.CallTimeout(), userID)
		if err != nil {
			logging.ForComponent("rpc").
				WithFields(logrus.Fields{
					"rpc":     "rbac.ListAccessibleOrgs",
					"userId":  userID,
					"reqName": listToolName,
				}).
				WithError(err).
				Error("rbac list accessible orgs RPC failed")

			return mcp.NewToolResultError(fmt.Sprintf(`Failed to determine accessible organizations: %v

The RBAC service confirms which organizations the authenticated user can access. Ensure the RBAC service is reachable and the user ID header is valid, then retry.`, err)), nil
		}

		accessibleSet, dedupIDs := normalizeAccessibleIDs(accessibleIDs)
		if len(accessibleSet) == 0 {
			result := listResult{Organizations: []organizationSummary{}}
			markdown := formatOrganizationsMarkdown(result.Organizations, mode, "")
			markdown = shared.TruncateResponse(markdown, shared.MaxResponseChars)

			return &mcp.CallToolResult{
				Content:           []mcp.Content{mcp.NewTextContent(markdown)},
				StructuredContent: result,
			}, nil
		}

		callCtx, cancel := context.WithTimeout(ctx, api.CallTimeout())
		resp, err := client.DescribeMany(callCtx, &orgpb.DescribeManyRequest{OrgIds: dedupIDs})
		cancel()
		if err != nil {
			logging.ForComponent("rpc").
				WithFields(logrus.Fields{
					"rpc":      "organization.DescribeMany",
					"userId":   userID,
					"orgCount": len(dedupIDs),
					"reqName":  listToolName,
				}).
				WithError(err).
				Error("organization describe many RPC failed")

			return mcp.NewToolResultError(fmt.Sprintf(`Organization lookup failed: %v

The organization service could not describe the permitted organizations. Retry in a few moments or verify the service connectivity.`, err)), nil
		}

		filtered, mismatches := filterAccessibleOrganizations(resp.GetOrganizations(), accessibleSet)
		if len(mismatches) > 0 {
			for _, org := range mismatches {
				if org == nil {
					continue
				}
				shared.ReportScopeMismatch(shared.ScopeMismatchMetadata{
					Tool:             listToolName,
					ResourceType:     "organization",
					ResourceID:       org.GetOrgId(),
					RequestOrgID:     "(multiple)",
					ResourceOrgID:    org.GetOrgId(),
					RequestProjectID: "",
				})
			}
			return shared.ScopeMismatchError(listToolName, "organization"), nil
		}
		if len(filtered) == 0 {
			result := listResult{Organizations: []organizationSummary{}}
			markdown := formatOrganizationsMarkdown(result.Organizations, mode, "")
			markdown = shared.TruncateResponse(markdown, shared.MaxResponseChars)

			return &mcp.CallToolResult{
				Content:           []mcp.Content{mcp.NewTextContent(markdown)},
				StructuredContent: result,
			}, nil
		}

		sortOrganizations(filtered)

		if offset < 0 {
			offset = 0
		}
		if offset > len(filtered) {
			offset = len(filtered)
		}

		end := offset + limit
		if end > len(filtered) {
			end = len(filtered)
		}

		includeDetails := mode == "detailed"
		orgs := make([]organizationSummary, 0, end-offset)
		for _, o := range filtered[offset:end] {
			orgs = append(orgs, summarizeOrganization(o, includeDetails))
		}

		nextCursor := ""
		if end < len(filtered) {
			if token, err := encodeCursorOffset(end); err == nil {
				nextCursor = token
			} else {
				logging.ForComponent("tools").
					WithField("tool", listToolName).
					WithError(err).
					Warn("failed to encode pagination cursor")
			}
		}

		result := listResult{
			Organizations: orgs,
			NextCursor:    nextCursor,
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

func listAccessibleOrgIDs(ctx context.Context, client rbacpb.RBACClient, timeout time.Duration, userID string) ([]string, error) {
	callCtx, cancel := context.WithTimeout(ctx, timeout)
	defer cancel()

	resp, err := client.ListAccessibleOrgs(callCtx, &rbacpb.ListAccessibleOrgsRequest{UserId: userID})
	if err != nil {
		return nil, err
	}
	return resp.GetOrgIds(), nil
}

func normalizeAccessibleIDs(ids []string) (map[string]struct{}, []string) {
	set := make(map[string]struct{}, len(ids))
	dedup := make([]string, 0, len(ids))
	for _, id := range ids {
		norm := normalizeOrgID(id)
		if norm == "" {
			continue
		}
		if _, exists := set[norm]; exists {
			continue
		}
		set[norm] = struct{}{}
		dedup = append(dedup, id)
	}
	return set, dedup
}

func filterAccessibleOrganizations(orgs []*orgpb.Organization, allowed map[string]struct{}) ([]*orgpb.Organization, []*orgpb.Organization) {
	if len(orgs) == 0 {
		return nil, nil
	}

	filtered := make([]*orgpb.Organization, 0, len(orgs))
	mismatches := make([]*orgpb.Organization, 0)
	for _, org := range orgs {
		if org == nil {
			continue
		}
		norm := normalizeOrgID(org.GetOrgId())
		if _, ok := allowed[norm]; ok {
			filtered = append(filtered, org)
			continue
		}
		mismatches = append(mismatches, org)
	}
	return filtered, mismatches
}

func sortOrganizations(orgs []*orgpb.Organization) {
	sort.SliceStable(orgs, func(i, j int) bool {
		a := orgs[i]
		b := orgs[j]

		aName := strings.ToLower(strings.TrimSpace(a.GetName()))
		bName := strings.ToLower(strings.TrimSpace(b.GetName()))
		if aName != bName {
			return aName < bName
		}

		aUsername := strings.ToLower(strings.TrimSpace(a.GetOrgUsername()))
		bUsername := strings.ToLower(strings.TrimSpace(b.GetOrgUsername()))
		if aUsername != bUsername {
			return aUsername < bUsername
		}

		return normalizeOrgID(a.GetOrgId()) < normalizeOrgID(b.GetOrgId())
	})
}

type cursorPayload struct {
	Offset int `json:"offset"`
}

func parseCursorOffset(raw string) (int, error) {
	if raw == "" {
		return 0, nil
	}
	if strings.HasPrefix(raw, "v1:") {
		data, err := base64.StdEncoding.DecodeString(strings.TrimPrefix(raw, "v1:"))
		if err != nil {
			return 0, fmt.Errorf("decode cursor: %w", err)
		}
		var payload cursorPayload
		if err := json.Unmarshal(data, &payload); err != nil {
			return 0, fmt.Errorf("parse cursor: %w", err)
		}
		if payload.Offset < 0 {
			payload.Offset = 0
		}
		return payload.Offset, nil
	}
	if n, err := strconv.Atoi(raw); err == nil {
		if n < 0 {
			return 0, fmt.Errorf("cursor offset cannot be negative")
		}
		return n, nil
	}
	// Unknown legacy cursor – treat as start of list.
	return 0, nil
}

func encodeCursorOffset(offset int) (string, error) {
	if offset <= 0 {
		return "", nil
	}
	payload := cursorPayload{Offset: offset}
	raw, err := json.Marshal(payload)
	if err != nil {
		return "", err
	}
	return "v1:" + base64.StdEncoding.EncodeToString(raw), nil
}

func normalizeOrgID(id string) string {
	return strings.ToLower(strings.TrimSpace(id))
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
