package jobs

import (
	"github.com/mark3labs/mcp-go/server"

	"github.com/semaphoreio/semaphore/mcp_server/pkg/internalapi"
)

// Register wires job-related tools into the MCP server.
func Register(s *server.MCPServer, api internalapi.Provider) {
	s.AddTool(newDescribeTool(), describeHandler(api))
	s.AddTool(newLogsTool(), logsHandler(api))
}
