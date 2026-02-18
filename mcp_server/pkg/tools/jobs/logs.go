package jobs

import (
	"context"
	"fmt"
	"strconv"
	"strings"

	"github.com/mark3labs/mcp-go/mcp"
	"github.com/mark3labs/mcp-go/server"
	"github.com/sirupsen/logrus"

	"github.com/semaphoreio/semaphore/mcp_server/pkg/authz"
	loghubpb "github.com/semaphoreio/semaphore/mcp_server/pkg/internal_api/loghub"
	loghub2pb "github.com/semaphoreio/semaphore/mcp_server/pkg/internal_api/loghub2"
	orgpb "github.com/semaphoreio/semaphore/mcp_server/pkg/internal_api/organization"
	"github.com/semaphoreio/semaphore/mcp_server/pkg/internalapi"
	"github.com/semaphoreio/semaphore/mcp_server/pkg/logging"
	"github.com/semaphoreio/semaphore/mcp_server/pkg/tools/internal/shared"
	"github.com/semaphoreio/semaphore/mcp_server/pkg/utils"
)

const (
	logsToolName         = "jobs_logs"
	loghubSource         = "loghub"
	loghub2Source        = "loghub2"
	loghub2TokenDuration = 300
	maxLogPreviewLines   = 200
	errLoghubMissing     = "loghub gRPC endpoint is not configured"
	errLoghub2Missing    = "loghub2 gRPC endpoint is not configured"
)

func logsFullDescription() string {
	return `Fetch recent log output for a job.

Use this after jobs_describe indicates a failure or long-running job.

Outputs:
- Hosted jobs: returns a preview of the most recent log lines (up to 200) and a nextCursor for pagination.
- Self-hosted jobs: returns a temporary log token (300s TTL) and instructions for downloading full logs.

Examples:
1. Fetch latest job logs:
   jobs_logs(job_id="...")

2. Paginate through more logs:
   jobs_logs(job_id="...", cursor="next-page-token")

3. Get logs for self-hosted job:
   jobs_logs(job_id="...")

Typical workflow:
1. jobs_describe(job_id="...") → identify failing job
2. jobs_logs(job_id="...") → view latest log lines
3. If more logs needed, call again with cursor from the previous response.
4. For self-hosted jobs, use the returned token in a follow-up HTTPS request.
`
}

type logsResult struct {
	JobID            string   `json:"jobId"`
	Source           string   `json:"source"`
	Preview          []string `json:"preview,omitempty"`
	NextCursor       string   `json:"nextCursor,omitempty"`
	Final            bool     `json:"Final,omitempty"`
	StartLine        int      `json:"startLine,omitempty"`
	PreviewTruncated bool     `json:"previewTruncated,omitempty"`
	Token            string   `json:"token,omitempty"`
	TokenType        string   `json:"tokenType,omitempty"`
	TokenTtlSeconds  uint32   `json:"tokenTtlSeconds,omitempty"`
	LogsURL          string   `json:"logsUrl,omitempty"`
}

func newLogsTool(name, description string) mcp.Tool {
	return mcp.NewTool(
		name,
		mcp.WithDescription(description),
		mcp.WithString(
			"job_id",
			mcp.Required(),
			mcp.Description("Job UUID to fetch logs for (format: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx)."),
			mcp.Pattern(`^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$`),
		),
		mcp.WithString(
			"cursor",
			mcp.Description("Pagination cursor returned by a previous call’s nextCursor. Omit to start from the latest logs."),
		),
		mcp.WithReadOnlyHintAnnotation(true),
		mcp.WithIdempotentHintAnnotation(true),
		mcp.WithOpenWorldHintAnnotation(true),
	)
}

func logsHandler(api internalapi.Provider) server.ToolHandlerFunc {
	return func(ctx context.Context, req mcp.CallToolRequest) (*mcp.CallToolResult, error) {
		jobIDRaw, err := req.RequireString("job_id")
		if err != nil {
			return mcp.NewToolResultError("job_id is required. Provide the job UUID shown by jobs_describe."), nil
		}

		jobID := strings.TrimSpace(jobIDRaw)
		if err := shared.ValidateUUID(jobID, "job_id"); err != nil {
			return mcp.NewToolResultError(err.Error()), nil
		}

		userID := strings.ToLower(strings.TrimSpace(req.Header.Get("X-Semaphore-User-ID")))
		if err := shared.ValidateUUID(userID, "x-semaphore-user-id header"); err != nil {
			return mcp.NewToolResultError(fmt.Sprintf(`%v

The authentication layer must inject the X-Semaphore-User-ID header so we can enforce project permissions before streaming job logs.

Troubleshooting:
- Ensure requests pass through the authenticated proxy
- Verify the header value is a UUID (xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx)
- Retry once the header is present`, err)), nil
		}

		cursor := strings.TrimSpace(req.GetString("cursor", ""))
		startingLine, err := parseCursor(cursor)
		if err != nil {
			return mcp.NewToolResultError(err.Error()), nil
		}

		job, err := fetchJob(ctx, api, jobID)
		if err != nil {
			return mcp.NewToolResultError(err.Error()), nil
		}
		jobProjectID := strings.TrimSpace(job.GetProjectId())
		jobOrg := strings.TrimSpace(job.GetOrganizationId())
		if err := shared.ValidateUUID(jobOrg, "job organization_id"); err != nil {
			return mcp.NewToolResultError(err.Error()), nil
		}
		if err := shared.ValidateUUID(jobProjectID, "job project_id"); err != nil {
			return mcp.NewToolResultError(err.Error()), nil
		}

		tracker := shared.TrackToolExecution(ctx, logsToolName, jobOrg)
		defer tracker.Cleanup()

		if err := shared.EnsureReadToolsFeature(ctx, api, jobOrg); err != nil {
			return mcp.NewToolResultError(err.Error()), nil
		}

		if err := authz.CheckProjectPermission(ctx, api, userID, jobOrg, jobProjectID, projectViewPermission); err != nil {
			return shared.ProjectAuthorizationError(err, jobOrg, jobProjectID, projectViewPermission), nil
		}

		var (
			result  *mcp.CallToolResult
			callErr error
		)

		if job.GetSelfHosted() {
			orgUsername, err := fetchOrgUsername(ctx, api, jobOrg)
			if err != nil {
				logging.ForComponent("tools").
					WithField("orgId", jobOrg).
					WithError(err).
					Warn("failed to resolve org username for logs URL")
			}
			result, callErr = fetchSelfHostedLogs(ctx, api, jobID, orgUsername)
		} else {
			result, callErr = fetchHostedLogs(ctx, api, jobID, startingLine)
		}
		if callErr != nil {
			return result, callErr
		}
		if result != nil && !result.IsError {
			// For self-hosted jobs, also verify that a token was actually generated
			if job.GetSelfHosted() {
				if structured, ok := result.StructuredContent.(logsResult); ok && structured.Token != "" {
					tracker.MarkSuccess()
				}
			} else {
				tracker.MarkSuccess()
			}
		}
		return result, nil
	}
}

func parseCursor(cursor string) (int, error) {
	if cursor == "" {
		return -1, nil
	}
	value, err := strconv.Atoi(cursor)
	if err != nil || value < 0 {
		return -1, fmt.Errorf("cursor must be a non-negative integer produced by the previous response (got %q)", cursor)
	}
	return value, nil
}

func fetchHostedLogs(ctx context.Context, api internalapi.Provider, jobID string, startingLine int) (*mcp.CallToolResult, error) {
	client := api.Loghub()
	if client == nil {
		return mcp.NewToolResultError(errLoghubMissing), nil
	}

	request := &loghubpb.GetLogEventsRequest{JobId: jobID}
	if startingLine >= 0 {
		offset, err := utils.IntToInt32(startingLine, "cursor offset")
		if err != nil {
			return mcp.NewToolResultError(err.Error()), nil
		}
		request.StartingLine = offset
	}

	callCtx, cancel := context.WithTimeout(ctx, api.CallTimeout())
	defer cancel()

	resp, err := client.GetLogEvents(callCtx, request)
	if err != nil {
		logging.ForComponent("rpc").
			WithFields(logrus.Fields{
				"rpc":   "loghub.GetLogEvents",
				"jobId": jobID,
			}).
			WithError(err).
			Error("gRPC call failed")
		return mcp.NewToolResultError(fmt.Sprintf("loghub RPC failed: %v", err)), nil
	}

	if err := shared.CheckResponseStatus(resp.GetStatus()); err != nil {
		logging.ForComponent("rpc").
			WithFields(logrus.Fields{
				"rpc":   "loghub.GetLogEvents",
				"jobId": jobID,
			}).
			WithError(err).
			Warn("loghub returned non-OK status")
		return mcp.NewToolResultError(err.Error()), nil
	}

	events := append([]string(nil), resp.GetEvents()...)
	totalEvents := len(events)
	displayStartLine := 0
	truncated := false
	relativeStart := 0
	relativeEnd := totalEvents

	if startingLine < 0 {
		if totalEvents > maxLogPreviewLines {
			displayStartLine = totalEvents - maxLogPreviewLines
			relativeStart = displayStartLine
			truncated = true
		}
	} else {
		displayStartLine = startingLine
		truncated = true
		relativeEnd = maxLogPreviewLines
		if relativeEnd > totalEvents {
			relativeEnd = totalEvents
		}
	}

	if relativeStart < 0 {
		relativeStart = 0
	}
	if relativeEnd > totalEvents {
		relativeEnd = totalEvents
	}
	if relativeStart > relativeEnd {
		relativeStart = relativeEnd
	}

	displayEvents := events[relativeStart:relativeEnd]

	var nextCursor string
	if displayStartLine > 0 {
		prev := displayStartLine - maxLogPreviewLines
		if prev < 0 {
			prev = 0
		}
		nextCursor = strconv.Itoa(prev)
	}

	result := logsResult{
		JobID:            jobID,
		Source:           loghubSource,
		Preview:          displayEvents,
		Final:            resp.GetFinal(),
		StartLine:        displayStartLine,
		PreviewTruncated: truncated,
	}

	if nextCursor != "" {
		result.NextCursor = nextCursor
	}

	markdown := formatHostedLogsMarkdown(result)
	markdown = shared.TruncateResponse(markdown, shared.MaxResponseChars)

	return &mcp.CallToolResult{
		Content: []mcp.Content{
			mcp.NewTextContent(markdown),
		},
		StructuredContent: result,
	}, nil
}

func fetchSelfHostedLogs(ctx context.Context, api internalapi.Provider, jobID, orgUsername string) (*mcp.CallToolResult, error) {
	client := api.Loghub2()
	if client == nil {
		return mcp.NewToolResultError(errLoghub2Missing), nil
	}

	request := &loghub2pb.GenerateTokenRequest{
		JobId:    jobID,
		Type:     loghub2pb.TokenType_PULL,
		Duration: loghub2TokenDuration,
	}

	callCtx, cancel := context.WithTimeout(ctx, api.CallTimeout())
	defer cancel()

	resp, err := client.GenerateToken(callCtx, request)
	if err != nil {
		logging.ForComponent("rpc").
			WithFields(logrus.Fields{
				"rpc":   "loghub2.GenerateToken",
				"jobId": jobID,
			}).
			WithError(err).
			Error("gRPC call failed")
		return mcp.NewToolResultError(fmt.Sprintf("loghub2 RPC failed: %v", err)), nil
	}

	logsURL := buildLogsURL(api.BaseURL(), orgUsername, jobID, resp.GetToken())

	result := logsResult{
		JobID:           jobID,
		Source:          loghub2Source,
		Token:           resp.GetToken(),
		TokenType:       tokenTypeToString(resp.GetType()),
		TokenTtlSeconds: loghub2TokenDuration,
		LogsURL:         logsURL,
	}

	markdown := formatSelfHostedLogsMarkdown(result)
	markdown = shared.TruncateResponse(markdown, shared.MaxResponseChars)

	return &mcp.CallToolResult{
		Content: []mcp.Content{
			mcp.NewTextContent(markdown),
		},
		StructuredContent: result,
	}, nil
}

func formatHostedLogsMarkdown(result logsResult) string {
	mb := shared.NewMarkdownBuilder()

	mb.H1(fmt.Sprintf("Hosted Logs Preview for Job %s", result.JobID))

	if len(result.Preview) == 0 {
		mb.Paragraph("No log lines were returned. The job may not have produced output yet, or all logs have been consumed.")
	} else {
		start := result.StartLine
		end := result.StartLine + len(result.Preview) - 1
		if start <= 0 {
			start = 0
		}

		mb.Paragraph(fmt.Sprintf("Showing log lines %d-%d.", start, end))
		mb.Raw("```\n")
		mb.Raw(strings.Join(result.Preview, "\n"))
		mb.Raw("\n```\n")

		if result.PreviewTruncated {
			if result.NextCursor != "" {
				mb.Paragraph(fmt.Sprintf("⚠️ Preview is truncated. If you want to see the full log, paginate using `cursor=\"%s\"` to retrieve additional lines.", result.NextCursor))
			} else {
				mb.Paragraph("⚠️ Preview is truncated. No further logs are available at this time.")
			}
		}
	}

	if result.Final {
		mb.Paragraph("✅ This job is finished and it reported final logs.")
	} else {
		mb.Paragraph("ℹ️ Job is still running and logs are still streaming. Retry shortly without cursor to fetch most recent output.")
	}

	mb.Line()

	return mb.String()
}

func formatSelfHostedLogsMarkdown(result logsResult) string {
	mb := shared.NewMarkdownBuilder()

	mb.H1(fmt.Sprintf("Self-Hosted Logs for Job %s", result.JobID))
	mb.Paragraph("This job ran on a self-hosted agent. Logs are available via a short-lived token.")

	mb.KeyValue("Token Type", strings.ToUpper(result.TokenType))
	mb.KeyValue("Expires In", fmt.Sprintf("%d seconds", result.TokenTtlSeconds))

	if result.Token != "" && result.LogsURL != "" {
		mb.KeyValue("Logs URL", fmt.Sprintf("`%s`", result.LogsURL))
		mb.Paragraph("To retrieve logs, use the following command:")
		mb.Raw("```bash\n")
		mb.Raw(fmt.Sprintf("curl \"%s\"", result.LogsURL))
		mb.Raw("\n```\n")
	} else if result.Token != "" {
		mb.Paragraph("Use the following JWT within the TTL to stream logs:")
		mb.Raw("```\n")
		mb.Raw(result.Token)
		mb.Raw("\n```\n")
		mb.Paragraph("⚠️ Could not construct a full logs URL. Use the token above with your workspace URL.")
	} else {
		mb.Paragraph("⚠️ No token was returned. Retry the request or contact support if the problem persists.")
	}

	mb.Line()
	mb.Paragraph("Remember to rotate tokens promptly and never store them in persistent logs.")

	return mb.String()
}

func tokenTypeToString(tokenType loghub2pb.TokenType) string {
	if name, ok := loghub2pb.TokenType_name[int32(tokenType)]; ok {
		return strings.ToLower(name)
	}
	return "unknown"
}

func fetchOrgUsername(ctx context.Context, api internalapi.Provider, orgID string) (string, error) {
	client := api.Organizations()
	if client == nil {
		return "", fmt.Errorf("organization service not configured")
	}

	callCtx, cancel := context.WithTimeout(ctx, api.CallTimeout())
	defer cancel()

	resp, err := client.Describe(callCtx, &orgpb.DescribeRequest{OrgId: orgID})
	if err != nil {
		return "", err
	}

	if resp.GetOrganization() == nil {
		return "", fmt.Errorf("organization not found")
	}

	return resp.GetOrganization().GetOrgUsername(), nil
}

func buildLogsURL(baseURL, orgUsername, jobID, token string) string {
	if orgUsername == "" || token == "" {
		return ""
	}
	return fmt.Sprintf("https://%s.%s/api/v1/logs/%s?jwt=%s", orgUsername, baseURL, jobID, token)
}
