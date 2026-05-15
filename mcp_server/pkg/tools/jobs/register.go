package jobs

import (
	"github.com/mark3labs/mcp-go/server"

	"github.com/semaphoreio/semaphore/mcp_server/pkg/internalapi"
)

// Register wires job-related tools into the MCP server.
func Register(s *server.MCPServer, api internalapi.Provider) {
	descH := describeHandler(api)
	s.AddTool(newDescribeTool(describeToolName, describeFullDescription()), descH)

	logsH := logsHandler(api, downloadSelfHostedLogs)
	s.AddTool(newLogsTool(logsToolName, logsFullDescription()), logsH)

	artifactJobLogsH := artifactJobLogsHandler(api)
	s.AddTool(newArtifactJobLogsTool(artifactJobLogsToolName, artifactJobLogsFullDescription()), artifactJobLogsH)
}
