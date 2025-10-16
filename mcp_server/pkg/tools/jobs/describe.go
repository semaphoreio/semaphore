package jobs

import (
	"context"

	"github.com/mark3labs/mcp-go/mcp"
	"github.com/mark3labs/mcp-go/server"

	"github.com/semaphoreio/semaphore/mcp_server/pkg/internalapi"
)

const describeToolName = "jobs.describe"

func newDescribeTool() mcp.Tool {
	return mcp.NewTool(
		describeToolName,
		mcp.WithDescription("Describe a job by ID."),
		mcp.WithString(
			"job_id",
			mcp.Required(),
			mcp.Description("Job UUID to describe."),
		),
	)
}

func describeHandler(api internalapi.Provider) server.ToolHandlerFunc {
	return func(ctx context.Context, req mcp.CallToolRequest) (*mcp.CallToolResult, error) {
		jobID, err := req.RequireString("job_id")
		if err != nil {
			return mcp.NewToolResultError(err.Error()), nil
		}

		job, err := fetchJob(ctx, api, jobID)
		if err != nil {
			return mcp.NewToolResultError(err.Error()), nil
		}

		return mcp.NewToolResultStructuredOnly(summarizeJob(job)), nil
	}
}
