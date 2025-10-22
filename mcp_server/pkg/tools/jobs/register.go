package jobs

import (
	"github.com/mark3labs/mcp-go/server"

	"github.com/semaphoreio/semaphore/mcp_server/pkg/internalapi"
)

// Register wires job-related tools into the MCP server.
func Register(s *server.MCPServer, api internalapi.Provider) {
	descH := describeHandler(api)
	s.AddTool(newDescribeTool(describeToolName, describeFullDescription()), descH)
	s.AddTool(newDescribeTool(legacyDescribeToolName, describeDeprecatedDescription()), descH)

	logsH := logsHandler(api)
	s.AddTool(newLogsTool(logsToolName, logsFullDescription()), logsH)
	s.AddTool(newLogsTool(legacyLogsToolName, logsDeprecatedDescription()), logsH)
}
