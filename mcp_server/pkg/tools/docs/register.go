package docs

import (
	"os"

	"github.com/mark3labs/mcp-go/server"
	"github.com/semaphoreio/semaphore/mcp_server/pkg/docssearch"
	"github.com/semaphoreio/semaphore/mcp_server/pkg/logging"
)

const (
	defaultIndexPath = "/app/docssearch/index"
	defaultDocsRoot  = "/app/docssearch/docs"
)

// Register adds the documentation search tool to the MCP server.
func Register(s *server.MCPServer) {
	indexPath := os.Getenv("DOCSSEARCH_INDEX_PATH")
	if indexPath == "" {
		indexPath = defaultIndexPath
	}

	docsRoot := os.Getenv("DOCSSEARCH_DOCS_ROOT")
	if docsRoot == "" {
		docsRoot = defaultDocsRoot
	}

	client, err := docssearch.New(indexPath, docsRoot)
	if err != nil {
		logging.ForComponent("docs").
			WithError(err).
			Warn("Failed to initialize docssearch client, docs_search tool will not be available")
		return
	}

	s.AddTool(newSearchTool(searchToolName, searchFullDescription()), searchHandler(client))

	// Register docs as a resource template (not a tool) for reading full content
	s.AddResourceTemplate(newDocsResourceTemplate(), docsResourceHandler(client))
}
