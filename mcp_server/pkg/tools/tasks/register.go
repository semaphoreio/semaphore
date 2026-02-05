package tasks

import (
	"github.com/mark3labs/mcp-go/server"

	"github.com/semaphoreio/semaphore/mcp_server/pkg/internalapi"
)

const (
	listToolName     = "tasks_list"
	describeToolName = "tasks_describe"
	runToolName      = "tasks_run"

	defaultLimit = 20
	maxLimit     = 100

	missingSchedulerError = "scheduler gRPC endpoint is not configured"

	schedulerViewPermission = "project.scheduler.view"
	schedulerRunPermission  = "project.scheduler.run_manually"
)

// Register wires task tooling into the MCP server.
func Register(s *server.MCPServer, api internalapi.Provider) {
	s.AddTool(newListTool(listToolName, listFullDescription()), listHandler(api))
	s.AddTool(newDescribeTool(describeToolName, describeFullDescription()), describeHandler(api))
	s.AddTool(newRunTool(runToolName, runFullDescription()), runHandler(api))
}
