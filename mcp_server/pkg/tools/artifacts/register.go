package artifacts

import (
	"github.com/mark3labs/mcp-go/server"

	"github.com/semaphoreio/semaphore/mcp_server/pkg/internalapi"
)

const (
	listToolName      = "artifacts_list"
	signedURLToolName = "artifacts_signed_url"

	// Both permissions are required for artifact read operations.
	// This mirrors the API contract for listing and signed URL retrieval.
	artifactsListPermission = "project.view"

	artifactsDownloadPermission = "project.artifacts.view"
)

var artifactsRequiredPermissions = []string{
	artifactsListPermission,
	artifactsDownloadPermission,
}

// Register wires artifact tools into the MCP server.
func Register(s *server.MCPServer, api internalapi.Provider) {
	if s == nil {
		return
	}

	s.AddTool(newListTool(listToolName, listFullDescription()), listHandler(api))
	s.AddTool(newSignedURLTool(signedURLToolName, signedURLFullDescription()), signedURLHandler(api))
}
