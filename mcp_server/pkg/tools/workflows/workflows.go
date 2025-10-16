package workflows

import (
	"context"
	"fmt"
	"strings"

	"github.com/mark3labs/mcp-go/mcp"
	"github.com/mark3labs/mcp-go/server"

	workflowpb "github.com/semaphoreio/semaphore/mcp_server/pkg/internal_api/plumber_w_f.workflow"
	"github.com/semaphoreio/semaphore/mcp_server/pkg/internalapi"
	"github.com/semaphoreio/semaphore/mcp_server/pkg/tools/internal/shared"
)

const (
	listToolName         = "workflows.list"
	defaultLimit         = 20
	maxLimit             = 100
	missingWorkflowError = "workflow gRPC endpoint is not configured"
)

// Register wires the workflows tool into the MCP server.
func Register(s *server.MCPServer, api internalapi.Provider) {
	s.AddTool(newListTool(), listHandler(api))
}

func newListTool() mcp.Tool {
	return mcp.NewTool(
		listToolName,
		mcp.WithDescription("List workflows for a project."),
		mcp.WithString("project_id",
			mcp.Required(),
			mcp.Description("Project UUID to scope the workflow search."),
		),
		mcp.WithString("organization_id",
			mcp.Description("Optional organization UUID filter."),
		),
		mcp.WithString("branch",
			mcp.Description("Filter workflows by branch name."),
		),
		mcp.WithString("requester_id",
			mcp.Description("Filter workflows by the originating requester."),
		),
		mcp.WithString("cursor",
			mcp.Description("Opaque pagination cursor returned by previous calls."),
		),
		mcp.WithNumber("limit",
			mcp.Description("Maximum number of workflows to return."),
			mcp.Min(1),
			mcp.Max(maxLimit),
			mcp.DefaultNumber(defaultLimit),
		),
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

		projectID, err := req.RequireString("project_id")
		if err != nil {
			return mcp.NewToolResultError(err.Error()), nil
		}

		limit := req.GetInt("limit", defaultLimit)
		if limit <= 0 {
			limit = defaultLimit
		} else if limit > maxLimit {
			limit = maxLimit
		}

		request := &workflowpb.ListKeysetRequest{
			ProjectId: projectID,
			PageSize:  int32(limit),
			PageToken: strings.TrimSpace(req.GetString("cursor", "")),
			Order:     workflowpb.ListKeysetRequest_BY_CREATION_TIME_DESC,
			Direction: workflowpb.ListKeysetRequest_NEXT,
		}

		if org := strings.TrimSpace(req.GetString("organization_id", "")); org != "" {
			request.OrganizationId = org
		}
		if branch := strings.TrimSpace(req.GetString("branch", "")); branch != "" {
			request.BranchName = branch
		}
		if requester := strings.TrimSpace(req.GetString("requester_id", "")); requester != "" {
			request.RequesterId = requester
		}

		callCtx, cancel := context.WithTimeout(ctx, api.CallTimeout())
		defer cancel()

		resp, err := client.ListKeyset(callCtx, request)
		if err != nil {
			return mcp.NewToolResultError(fmt.Sprintf("workflow list RPC failed: %v", err)), nil
		}

		if err := shared.CheckStatus(resp.GetStatus()); err != nil {
			return mcp.NewToolResultError(err.Error()), nil
		}

		workflows := make([]summary, 0, len(resp.GetWorkflows()))
		for _, wf := range resp.GetWorkflows() {
			workflows = append(workflows, summary{
				ID:              wf.GetWfId(),
				InitialPipeline: wf.GetInitialPplId(),
				ProjectID:       wf.GetProjectId(),
				OrganizationID:  wf.GetOrganizationId(),
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

		return mcp.NewToolResultStructuredOnly(result), nil
	}
}

func triggeredByToString(value workflowpb.TriggeredBy) string {
	if name, ok := workflowpb.TriggeredBy_name[int32(value)]; ok {
		return strings.ToLower(name)
	}
	return "unspecified"
}
