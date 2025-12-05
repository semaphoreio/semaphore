// Package docssearch provides a documentation search client using Bleve.
// This package can be imported directly into other Go services for in-process
// search without requiring gRPC.
package docssearch

import (
	"context"
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/semaphoreio/semaphore/mcp_server/pkg/docssearch/search"
)

// SearchResult represents a single search result.
type SearchResult struct {
	Path        string
	Title       string
	Snippet     string
	Score       float64
	Version     string
	DocType     string // "saas" or "versioned"
	Anchor      string
	Description string
}

// Document represents a full document.
type Document struct {
	Path    string
	Title   string
	Body    string
	Version string
	DocType string // "saas" or "versioned"
}

// SearchOption configures a search request.
type SearchOption func(*search.SearchRequest)

// WithVersion filters results to a specific version.
func WithVersion(version string) SearchOption {
	return func(r *search.SearchRequest) {
		r.Version = version
	}
}

// WithDocType filters results to SaaS or versioned docs.
func WithDocType(docType string) SearchOption {
	return func(r *search.SearchRequest) {
		switch docType {
		case "saas":
			r.DocType = search.DocTypeSaaS
		case "versioned":
			r.DocType = search.DocTypeVersioned
		}
	}
}

// WithLimit sets the maximum number of results.
func WithLimit(limit int) SearchOption {
	return func(r *search.SearchRequest) {
		// Clamp to valid int32 range to prevent overflow
		if limit < 0 {
			limit = 0
		} else if limit > 1000 {
			limit = 1000 // Reasonable max for search results
		}
		r.Limit = int32(limit) // #nosec G115 -- bounds checked above
	}
}

// WithOffset sets the result offset for pagination.
func WithOffset(offset int) SearchOption {
	return func(r *search.SearchRequest) {
		// Clamp to valid int32 range to prevent overflow
		if offset < 0 {
			offset = 0
		} else if offset > 10000 {
			offset = 10000 // Reasonable max for pagination offset
		}
		r.Offset = int32(offset) // #nosec G115 -- bounds checked above
	}
}

// WithPathPrefix filters results to a path subtree.
func WithPathPrefix(prefix string) SearchOption {
	return func(r *search.SearchRequest) {
		r.PathPrefix = prefix
	}
}

// Client provides documentation search capabilities.
type Client struct {
	searcher *search.Searcher
	docsRoot string
}

// New creates a new search client.
// indexPath is the path to the Bleve index directory.
// docsRoot is the path to the docs directory for GetDocument.
func New(indexPath, docsRoot string) (*Client, error) {
	s, err := search.Open(indexPath)
	if err != nil {
		return nil, fmt.Errorf("open index: %w", err)
	}
	return &Client{
		searcher: s,
		docsRoot: docsRoot,
	}, nil
}

// Close releases resources.
func (c *Client) Close() error {
	if c.searcher != nil {
		return c.searcher.Close()
	}
	return nil
}

// Search executes a search query with optional filters.
func (c *Client) Search(ctx context.Context, query string, opts ...SearchOption) ([]SearchResult, error) {
	req := &search.SearchRequest{
		Query: query,
		Limit: 10,
	}
	for _, opt := range opts {
		opt(req)
	}

	results, err := c.searcher.Search(req)
	if err != nil {
		return nil, err
	}

	var out []SearchResult
	for _, r := range results {
		out = append(out, SearchResult{
			Path:        r.Path,
			Title:       r.Title,
			Snippet:     r.Snippet,
			Score:       r.Score,
			Version:     r.Version,
			DocType:     r.DocType,
			Anchor:      r.Anchor,
			Description: r.Description,
		})
	}
	return out, nil
}

// GetDocument retrieves a document by path.
func (c *Client) GetDocument(ctx context.Context, path string) (*Document, error) {
	// Validate path doesn't escape docs root
	cleanPath := filepath.Clean(path)
	if filepath.IsAbs(cleanPath) || (len(cleanPath) > 0 && cleanPath[0] == '.') {
		return nil, fmt.Errorf("invalid path")
	}

	fullPath := filepath.Join(c.docsRoot, cleanPath)

	// Ensure the resolved path is within docsRoot (prevent path traversal)
	absDocsRoot, err := filepath.Abs(c.docsRoot)
	if err != nil {
		return nil, fmt.Errorf("invalid docs root: %w", err)
	}
	absFullPath, err := filepath.Abs(fullPath)
	if err != nil {
		return nil, fmt.Errorf("invalid path: %w", err)
	}
	if !strings.HasPrefix(absFullPath, absDocsRoot+string(filepath.Separator)) && absFullPath != absDocsRoot {
		return nil, fmt.Errorf("invalid path: outside docs root")
	}

	content, err := os.ReadFile(absFullPath) // #nosec G304 -- path validated above
	if err != nil {
		if os.IsNotExist(err) {
			return nil, fmt.Errorf("document not found: %s", path)
		}
		return nil, fmt.Errorf("read document: %w", err)
	}

	version, docType := inferVersionAndType(cleanPath)
	title := extractTitle(string(content))

	return &Document{
		Path:    cleanPath,
		Title:   title,
		Body:    string(content),
		Version: version,
		DocType: docType,
	}, nil
}

func inferVersionAndType(path string) (string, string) {
	// Check for SaaS docs (docs/...)
	if len(path) >= 5 && path[:5] == "docs/" {
		return "saas", "saas"
	}

	// Check for versioned docs (versioned_docs/version-XX/...)
	const prefix = "versioned_docs/version-"
	if len(path) >= len(prefix) && path[:len(prefix)] == prefix {
		rest := path[len(prefix):]
		slashIdx := -1
		for i, c := range rest {
			if c == '/' {
				slashIdx = i
				break
			}
		}
		if slashIdx > 0 {
			return rest[:slashIdx], "versioned"
		}
		return rest, "versioned"
	}

	return "", ""
}

func extractTitle(content string) string {
	lines := splitLines(content)
	inFrontMatter := false
	for _, line := range lines {
		if line == "---" {
			inFrontMatter = !inFrontMatter
			continue
		}
		if inFrontMatter {
			continue
		}
		if len(line) > 2 && line[0] == '#' && line[1] == ' ' {
			return line[2:]
		}
	}
	return ""
}

func splitLines(s string) []string {
	var lines []string
	start := 0
	for i := 0; i < len(s); i++ {
		if s[i] == '\n' {
			lines = append(lines, s[start:i])
			start = i + 1
		}
	}
	if start < len(s) {
		lines = append(lines, s[start:])
	}
	return lines
}
