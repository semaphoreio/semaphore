package docs

import (
	"context"
	"fmt"
	"path/filepath"
	"regexp"
	"strings"

	"github.com/mark3labs/mcp-go/mcp"
	"github.com/semaphoreio/semaphore/mcp_server/pkg/docssearch"
)

// markdownLinkRegex matches markdown links: [text](url)
// Does not match image links: ![alt](url)
var markdownLinkRegex = regexp.MustCompile(`\[([^\]]*)\]\(([^)]+)\)`)

const (
	docsResourceURIPrefix = "semaphore-docs://"
)

// newDocsResourceTemplate creates a resource template for Semaphore documentation.
func newDocsResourceTemplate() mcp.ResourceTemplate {
	return mcp.NewResourceTemplate(
		docsResourceURIPrefix+"{+path}",
		"Semaphore Documentation",
		mcp.WithTemplateDescription(`Access Semaphore CI/CD documentation files.

Use this resource to read the full content of documentation files found via docs_search.

URI format: semaphore-docs://{path}
Example: semaphore-docs://docs/using-semaphore/pipelines.md

The path should match paths returned by the docs_search tool.`),
		mcp.WithTemplateMIMEType("text/markdown"),
	)
}

// docsResourceHandler returns a handler for reading documentation resources.
func docsResourceHandler(client *docssearch.Client) func(ctx context.Context, request mcp.ReadResourceRequest) ([]mcp.ResourceContents, error) {
	return func(ctx context.Context, request mcp.ReadResourceRequest) ([]mcp.ResourceContents, error) {
		uri := request.Params.URI

		// Extract path from URI
		if !strings.HasPrefix(uri, docsResourceURIPrefix) {
			return nil, fmt.Errorf("invalid URI: must start with %s", docsResourceURIPrefix)
		}

		path := strings.TrimPrefix(uri, docsResourceURIPrefix)

		// Strip fragment/anchor if present (e.g., "docs/foo.md#section" -> "docs/foo.md")
		if idx := strings.Index(path, "#"); idx != -1 {
			path = path[:idx]
		}

		if path == "" {
			return nil, fmt.Errorf("invalid URI: path cannot be empty")
		}

		// Basic path validation - no parent directory traversal
		if strings.Contains(path, "..") {
			return nil, fmt.Errorf("invalid path: parent directory traversal not allowed")
		}

		doc, err := client.GetDocument(ctx, path)
		if err != nil {
			return nil, fmt.Errorf("document not found: %w", err)
		}

		// Rewrite relative links to absolute semaphore-docs:// URIs
		body := rewriteRelativeLinks(doc.Body, path)

		return []mcp.ResourceContents{
			mcp.TextResourceContents{
				URI:      uri,
				MIMEType: "text/markdown",
				Text:     body,
			},
		}, nil
	}
}

// rewriteRelativeLinks converts relative markdown links to absolute semaphore-docs:// URIs.
// This allows agents to follow links by using the resource URI directly.
func rewriteRelativeLinks(content, currentPath string) string {
	dir := filepath.Dir(currentPath)

	return markdownLinkRegex.ReplaceAllStringFunc(content, func(match string) string {
		// Check if this is an image link (preceded by !)
		// We need to check the character before the match in the original content
		idx := strings.Index(content, match)
		if idx > 0 && content[idx-1] == '!' {
			return match // Leave image links as-is
		}

		// Extract the link parts
		submatch := markdownLinkRegex.FindStringSubmatch(match)
		if len(submatch) != 3 {
			return match
		}

		linkText := submatch[1]
		linkPath := submatch[2]

		// Skip absolute URLs, anchors, and mailto links
		if strings.HasPrefix(linkPath, "http://") ||
			strings.HasPrefix(linkPath, "https://") ||
			strings.HasPrefix(linkPath, "mailto:") ||
			strings.HasPrefix(linkPath, "#") {
			return match
		}

		// Handle anchor in the link path
		var anchor string
		if anchorIdx := strings.Index(linkPath, "#"); anchorIdx != -1 {
			anchor = linkPath[anchorIdx:]
			linkPath = linkPath[:anchorIdx]
		}

		// Resolve relative path
		var resolvedPath string
		if strings.HasPrefix(linkPath, "/") {
			// Absolute path within docs - strip leading slash
			resolvedPath = strings.TrimPrefix(linkPath, "/")
		} else {
			// Relative path - resolve against current directory
			resolvedPath = filepath.Join(dir, linkPath)
			resolvedPath = filepath.Clean(resolvedPath)
		}

		// Add .md extension if missing and path doesn't have an extension
		if filepath.Ext(resolvedPath) == "" {
			resolvedPath += ".md"
		}

		// Build the new URI
		newURI := docsResourceURIPrefix + resolvedPath + anchor

		return fmt.Sprintf("[%s](%s)", linkText, newURI)
	})
}
