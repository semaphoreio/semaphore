package artifacts

import (
	"github.com/mark3labs/mcp-go/server"

	"github.com/semaphoreio/semaphore/mcp_server/pkg/internalapi"
)

const (
	listToolName      = "artifacts_list"
	signedURLToolName = "artifacts_signed_url"

	defaultListLimit = 200
	maxListLimit     = 1000
	maxListItems     = 5000

	// artifactsListPermission mirrors the front controller: browsing/listing
	// artifact entries only requires "project.view" (same as the UI endpoints).
	artifactsListPermission = "project.view"

	// artifactsDownloadPermission mirrors the front controller: downloading
	// artifacts (signed URL generation) requires "project.artifacts.view".
	artifactsDownloadPermission = "project.artifacts.view"
)

// Register wires artifact tools into the MCP server.
func Register(s *server.MCPServer, api internalapi.Provider) {
	if s == nil {
		return
	}

	s.AddTool(newListTool(listToolName, listFullDescription()), listHandler(api))
	s.AddTool(newSignedURLTool(signedURLToolName, signedURLFullDescription()), signedURLHandler(api))
}
