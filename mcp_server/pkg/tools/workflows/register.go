package workflows

import (
	"github.com/mark3labs/mcp-go/server"

	"github.com/semaphoreio/semaphore/mcp_server/pkg/internalapi"
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

// Register wires workflow tooling into the MCP server.
func Register(s *server.MCPServer, api internalapi.Provider) {
	s.AddTool(newSearchTool(searchToolName, searchFullDescription()), listHandler(api))
	s.AddTool(newRunTool(runToolName, runFullDescription()), runHandler(api))
}
