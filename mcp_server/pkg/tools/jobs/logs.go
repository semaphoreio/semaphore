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
   jobs_logs(job_id="...", organization_id="...")

2. Paginate through more logs:
   jobs_logs(job_id="...", organization_id="...", cursor="next-page-token")

3. Get logs for self-hosted job:
   jobs_logs(job_id="...", organization_id="...")

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
	Final            bool     `json:"final,omitempty"`
	StartLine        int      `json:"startLine,omitempty"`
	PreviewTruncated bool     `json:"previewTruncated,omitempty"`
	Token            string   `json:"token,omitempty"`
	TokenType        string   `json:"tokenType,omitempty"`
	TokenTtlSeconds  uint32   `json:"tokenTtlSeconds,omitempty"`
}

func newLogsTool(name, description string) mcp.Tool {
	return mcp.NewTool(
		name,
		mcp.WithDescription(description),
		mcp.WithString(
			"organization_id",
			mcp.Required(),
			mcp.Description("Organization UUID associated with the job. Cache this value after calling semaphore_organizations_list."),
			mcp.Pattern(`^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$`),
		),
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
		orgIDRaw, err := req.RequireString("organization_id")
		if err != nil {
			return mcp.NewToolResultError("organization_id is required. Provide the organization UUID returned by organizations_list."), nil
		}
		orgID := strings.TrimSpace(orgIDRaw)
		if err := shared.ValidateUUID(orgID, "organization_id"); err != nil {
			return mcp.NewToolResultError(err.Error()), nil
		}

		tracker := shared.TrackToolExecution(ctx, logsToolName, orgID)
		defer tracker.Cleanup()

		if err := shared.EnsureReadToolsFeature(ctx, api, orgID); err != nil {
			return mcp.NewToolResultError(err.Error()), nil
		}

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
		if jobOrg == "" || !strings.EqualFold(jobOrg, orgID) {
			shared.ReportScopeMismatch(shared.ScopeMismatchMetadata{
				Tool:              logsToolName,
				ResourceType:      "job",
				ResourceID:        jobID,
				RequestOrgID:      orgID,
				ResourceOrgID:     job.GetOrganizationId(),
				RequestProjectID:  "",
				ResourceProjectID: jobProjectID,
			})
			return shared.ScopeMismatchError(logsToolName, "organization"), nil
		}

		if jobProjectID == "" {
			shared.ReportScopeMismatch(shared.ScopeMismatchMetadata{
				Tool:              logsToolName,
				ResourceType:      "job",
				ResourceID:        jobID,
				RequestOrgID:      orgID,
				ResourceOrgID:     jobOrg,
				RequestProjectID:  "",
				ResourceProjectID: jobProjectID,
			})
			return shared.ScopeMismatchError(logsToolName, "project"), nil
		}

		if err := authz.CheckProjectPermission(ctx, api, userID, orgID, jobProjectID, projectViewPermission); err != nil {
			return shared.ProjectAuthorizationError(err, orgID, jobProjectID, projectViewPermission), nil
		}

		var (
			result  *mcp.CallToolResult
			callErr error
		)

		if job.GetSelfHosted() {
			result, callErr = fetchSelfHostedLogs(ctx, api, jobID)
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
		return 0, nil
	}
	value, err := strconv.Atoi(cursor)
	if err != nil || value < 0 {
		return 0, fmt.Errorf("cursor must be a non-negative integer produced by the previous response (got %q)", cursor)
	}
	return value, nil
}

func fetchHostedLogs(ctx context.Context, api internalapi.Provider, jobID string, startingLine int) (*mcp.CallToolResult, error) {
	client := api.Loghub()
	if client == nil {
		return mcp.NewToolResultError(errLoghubMissing), nil
	}

	request := &loghubpb.GetLogEventsRequest{JobId: jobID}
	if startingLine > 0 {
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
	displayEvents := events
	truncated := false
	if len(events) > maxLogPreviewLines {
		displayEvents, truncated = shared.TruncateList(events, maxLogPreviewLines)
	}

	result := logsResult{
		JobID:            jobID,
		Source:           loghubSource,
		Preview:          displayEvents,
		Final:            resp.GetFinal(),
		StartLine:        startingLine,
		PreviewTruncated: truncated,
	}

	if !resp.GetFinal() && len(events) > 0 {
		next := startingLine + len(events)
		result.NextCursor = strconv.Itoa(next)
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

func fetchSelfHostedLogs(ctx context.Context, api internalapi.Provider, jobID string) (*mcp.CallToolResult, error) {
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

	result := logsResult{
		JobID:           jobID,
		Source:          loghub2Source,
		Token:           resp.GetToken(),
		TokenType:       tokenTypeToString(resp.GetType()),
		TokenTtlSeconds: loghub2TokenDuration,
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

		mb.Paragraph(fmt.Sprintf("Showing log lines %d-%d (newest first).", start, end))
		mb.Raw("```\n")
		mb.Raw(strings.Join(result.Preview, "\n"))
		mb.Raw("\n```\n")

		if result.PreviewTruncated {
			mb.Paragraph(fmt.Sprintf("⚠️ Preview truncated to the most recent %d lines. Use pagination to retrieve the full log.", maxLogPreviewLines))
		}
	}

	if result.Final {
		mb.Paragraph("✅ This job reported final logs. No additional pages are available.")
	} else if result.NextCursor != "" {
		mb.Paragraph(fmt.Sprintf("📄 **More available**. Use `cursor=\"%s\"`", result.NextCursor))
	} else {
		mb.Paragraph("ℹ️ Logs are still streaming. Retry shortly for additional output.")
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

	if result.Token != "" {
		mb.Paragraph("Use the following JWT within the TTL to stream logs:")
		mb.Raw("```\n")
		mb.Raw(result.Token)
		mb.Raw("\n```\n")
		mb.Paragraph("Example:\n`curl \"https://<your-workspace>/api/v1/logs/" + result.JobID + "?jwt=<TOKEN>\"`\n")
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
