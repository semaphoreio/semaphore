package jobs

import (
	"context"
	"fmt"
	"strconv"
	"strings"

	"github.com/mark3labs/mcp-go/mcp"
	"github.com/mark3labs/mcp-go/server"
	"github.com/sirupsen/logrus"

	loghubpb "github.com/semaphoreio/semaphore/mcp_server/pkg/internal_api/loghub"
	loghub2pb "github.com/semaphoreio/semaphore/mcp_server/pkg/internal_api/loghub2"
	"github.com/semaphoreio/semaphore/mcp_server/pkg/internalapi"
	"github.com/semaphoreio/semaphore/mcp_server/pkg/logging"
	"github.com/semaphoreio/semaphore/mcp_server/pkg/tools/internal/shared"
)

const (
	logsToolName         = "jobs_logs"
	loghubSource         = "loghub"
	loghub2Source        = "loghub2"
	loghub2TokenDuration = 300
	errLoghubMissing     = "loghub gRPC endpoint is not configured"
	errLoghub2Missing    = "loghub2 gRPC endpoint is not configured"
)

type logsResult struct {
	JobID           string   `json:"jobId"`
	Source          string   `json:"source"`
	Preview         []string `json:"preview,omitempty"`
	NextCursor      string   `json:"nextCursor,omitempty"`
	Final           bool     `json:"final,omitempty"`
	Token           string   `json:"token,omitempty"`
	TokenType       string   `json:"tokenType,omitempty"`
	TokenTtlSeconds uint32   `json:"tokenTtlSeconds,omitempty"`
}

func newLogsTool() mcp.Tool {
	return mcp.NewTool(
		logsToolName,
		mcp.WithDescription("Fetch logs for a job."),
		mcp.WithString(
			"job_id",
			mcp.Required(),
			mcp.Description("Job UUID whose logs to fetch."),
		),
		mcp.WithString(
			"cursor",
			mcp.Description("Opaque cursor to continue log pagination."),
		),
	)
}

func logsHandler(api internalapi.Provider) server.ToolHandlerFunc {
	return func(ctx context.Context, req mcp.CallToolRequest) (*mcp.CallToolResult, error) {
		jobID, err := req.RequireString("job_id")
		if err != nil {
			return mcp.NewToolResultError(err.Error()), nil
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

		if job.GetSelfHosted() {
			return fetchSelfHostedLogs(ctx, api, jobID)
		}
		return fetchHostedLogs(ctx, api, jobID, startingLine)
	}
}

func parseCursor(cursor string) (int, error) {
	if cursor == "" {
		return 0, nil
	}
	value, err := strconv.Atoi(cursor)
	if err != nil || value < 0 {
		return 0, fmt.Errorf("invalid cursor value: %q", cursor)
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
		request.StartingLine = int32(startingLine)
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

	result := logsResult{
		JobID:   jobID,
		Source:  loghubSource,
		Preview: append([]string(nil), resp.GetEvents()...),
		Final:   resp.GetFinal(),
	}

	if !resp.GetFinal() && len(resp.GetEvents()) > 0 {
		next := startingLine + len(resp.GetEvents())
		result.NextCursor = strconv.Itoa(next)
	}

	return mcp.NewToolResultStructuredOnly(result), nil
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

	return mcp.NewToolResultStructuredOnly(result), nil
}

func tokenTypeToString(tokenType loghub2pb.TokenType) string {
	if name, ok := loghub2pb.TokenType_name[int32(tokenType)]; ok {
		return strings.ToLower(name)
	}
	return "unknown"
}
