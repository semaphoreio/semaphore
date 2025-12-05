package docs

import (
	"context"
	"fmt"
	"strings"

	"github.com/mark3labs/mcp-go/mcp"
	"github.com/mark3labs/mcp-go/server"
	"github.com/semaphoreio/semaphore/mcp_server/pkg/docssearch"
	"github.com/semaphoreio/semaphore/mcp_server/pkg/tools/internal/shared"
)

const (
	searchToolName = "docs_search"
	defaultLimit   = 10
	maxLimit       = 30
)

func searchFullDescription() string {
	return `Search Semaphore documentation for information about CI/CD features, configuration, and usage.

Use this when you need to answer:
- "How do I configure pipelines in Semaphore?"
- "What are the available environment variables?"
- "How do I set up caching?"
- "What is the YAML syntax for promotions?"

Parameters:
- query (required): Search term to find in the documentation
- limit (optional): Number of results to return (1-30, default 10)
- version (optional): Filter by doc version. Use "saas" for cloud docs (default), or "CE"/"EE" for self-hosted versioned docs (e.g., "CE", "EE", "CE-1.4", "EE-1.4")

After finding relevant documents, read the full content using the resource URI:
semaphore-docs://{path}

Example: semaphore-docs://docs/using-semaphore/pipelines.md

Response includes:
- File path and title for each matching document
- Snippet showing where the search term appears
- Score indicating relevance

Examples:
1. Search for pipeline configuration:
   docs_search(query="pipeline yaml")

2. Find information about caching:
   docs_search(query="cache dependencies")

3. Look up environment variables:
   docs_search(query="environment variables", limit=5)

4. Search self-hosted CE docs:
   docs_search(query="install", version="CE")`
}

func newSearchTool(name, description string) mcp.Tool {
	return mcp.NewTool(
		name,
		mcp.WithDescription(description),
		mcp.WithString("query",
			mcp.Required(),
			mcp.Description("Search term to find in Semaphore documentation."),
		),
		mcp.WithNumber("limit",
			mcp.Description("Number of results to return (1-30). Defaults to 10."),
			mcp.Min(1),
			mcp.Max(float64(maxLimit)),
			mcp.DefaultNumber(float64(defaultLimit)),
		),
		mcp.WithString("version",
			mcp.Description("Filter by doc version: 'saas' (default, cloud docs) or CE/EE versions for self-hosted (e.g., 'CE', 'EE', 'CE-1.4', 'EE-1.4')."),
		),
		mcp.WithReadOnlyHintAnnotation(true),
		mcp.WithIdempotentHintAnnotation(true),
	)
}

func searchHandler(client *docssearch.Client) server.ToolHandlerFunc {
	return func(ctx context.Context, req mcp.CallToolRequest) (*mcp.CallToolResult, error) {
		tracker := shared.TrackToolExecution(ctx, searchToolName, "")
		defer tracker.Cleanup()

		// Validate user ID header for future rate-limiting
		_, err := shared.ExtractUserID(req.Header.Get("X-Semaphore-User-ID"))
		if err != nil {
			return mcp.NewToolResultError(fmt.Sprintf(`%v

Authentication is required to use this tool.

Troubleshooting:
- Ensure requests pass through the auth proxy
- Verify the header value is a UUID (xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx)`, err)), nil
		}

		queryRaw, err := req.RequireString("query")
		if err != nil {
			return mcp.NewToolResultError("Missing required argument: query. Provide a search term to find in the documentation."), nil
		}

		query, err := shared.SanitizeDocsSearchQuery(queryRaw, "query")
		if err != nil {
			return mcp.NewToolResultError(err.Error()), nil
		}

		limit := req.GetInt("limit", defaultLimit)
		if limit <= 0 {
			limit = defaultLimit
		} else if limit > maxLimit {
			limit = maxLimit
		}

		// Build search options
		opts := []docssearch.SearchOption{
			docssearch.WithLimit(limit),
		}

		// Infer doc_type from version parameter
		version := req.GetString("version", "")
		if version == "" || version == "saas" {
			// Default to saas docs
			opts = append(opts, docssearch.WithDocType("saas"))
		} else if strings.HasPrefix(version, "CE") || strings.HasPrefix(version, "EE") {
			// CE/EE versions are versioned (self-hosted) docs
			opts = append(opts, docssearch.WithDocType("versioned"))
			opts = append(opts, docssearch.WithVersion(version))
		} else {
			// Unknown version format, try as-is with versioned doc_type
			opts = append(opts, docssearch.WithDocType("versioned"))
			opts = append(opts, docssearch.WithVersion(version))
		}

		results, err := client.Search(ctx, query, opts...)
		if err != nil {
			return mcp.NewToolResultError(fmt.Sprintf(`Documentation search failed: %v

Possible causes:
- Search index not available
- Invalid search query`, err)), nil
		}

		structuredResult := formatStructuredResult(results, query)
		markdown := formatMarkdown(results, query, limit)
		markdown = shared.TruncateResponse(markdown, shared.MaxResponseChars)

		tracker.MarkSuccess()
		return &mcp.CallToolResult{
			Content: []mcp.Content{
				mcp.NewTextContent(markdown),
			},
			StructuredContent: structuredResult,
		}, nil
	}
}

type searchResult struct {
	Results []docResult `json:"results"`
	Total   int         `json:"total"`
	Query   string      `json:"query"`
}

type docResult struct {
	Path    string  `json:"path"`
	Title   string  `json:"title"`
	Snippet string  `json:"snippet,omitempty"`
	Score   float64 `json:"score"`
	Version string  `json:"version"`
	DocType string  `json:"doc_type"`
}

func formatStructuredResult(results []docssearch.SearchResult, query string) searchResult {
	docs := make([]docResult, 0, len(results))
	for _, r := range results {
		docs = append(docs, docResult{
			Path:    r.Path,
			Title:   r.Title,
			Snippet: r.Snippet,
			Score:   r.Score,
			Version: r.Version,
			DocType: r.DocType,
		})
	}
	return searchResult{
		Results: docs,
		Total:   len(results),
		Query:   query,
	}
}

func formatMarkdown(results []docssearch.SearchResult, query string, limit int) string {
	mb := shared.NewMarkdownBuilder()

	header := fmt.Sprintf("Documentation Search Results (%d found)", len(results))
	mb.H1(header)

	if len(results) == 0 {
		mb.Paragraph(fmt.Sprintf("No documentation found matching '%s'.", query))
		mb.Paragraph("**Suggestions:**")
		mb.ListItem("Try different search terms")
		mb.ListItem("Use more general keywords")
		mb.ListItem("Check spelling")
		return mb.String()
	}

	for idx, r := range results {
		if idx > 0 {
			mb.Line()
		}

		title := r.Title
		if title == "" {
			title = r.Path
		}
		mb.H2(title)
		mb.KeyValue("Path", r.Path)
		mb.KeyValue("Version", r.Version)
		mb.KeyValue("Type", r.DocType)

		if r.Snippet != "" {
			mb.Paragraph("**Match:**")
			mb.Paragraph(fmt.Sprintf("> %s", strings.TrimSpace(r.Snippet)))
		}
	}

	return mb.String()
}
