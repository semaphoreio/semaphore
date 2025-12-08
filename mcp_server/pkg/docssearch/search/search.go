package search

import (
	"fmt"
	"html"
	"strings"

	"github.com/blevesearch/bleve/v2"
	"github.com/blevesearch/bleve/v2/search"
	"github.com/blevesearch/bleve/v2/search/query"
)

// DocType distinguishes SaaS docs from versioned self-hosted docs.
type DocType int

const (
	DocTypeUnspecified DocType = iota
	DocTypeSaaS
	DocTypeVersioned
)

// SearchRequest represents a search query with optional filters.
type SearchRequest struct {
	Query      string
	Version    string  // optional version filter (e.g. "saas", "CE", "EE")
	DocType    DocType // optional filter
	Limit      int32   // default from config
	Offset     int32
	PathPrefix string // optional filter to a subtree
}

// Result represents a search result.
type Result struct {
	Path        string
	Title       string
	Snippet     string
	Score       float64
	Version     string
	DocType     string
	Anchor      string
	Description string
}

// Searcher provides full-text search over the docs index.
type Searcher struct {
	index bleve.Index
}

// Open opens an existing Bleve index at the given path in read-only mode.
// Read-only mode is required for deployments where the index is baked into
// a read-only container filesystem (e.g., Kubernetes).
func Open(indexPath string) (*Searcher, error) {
	index, err := bleve.OpenUsing(indexPath, map[string]interface{}{
		"read_only": true,
	})
	if err != nil {
		return nil, fmt.Errorf("open index: %w", err)
	}
	return &Searcher{index: index}, nil
}

// Close closes the index.
func (s *Searcher) Close() error {
	return s.index.Close()
}

// Search executes a search query with optional filters.
func (s *Searcher) Search(req *SearchRequest) ([]Result, error) {
	q := buildQuery(req)

	limit := int(req.Limit)
	if limit <= 0 {
		limit = 10
	}
	offset := int(req.Offset)
	if offset < 0 {
		offset = 0
	}

	searchReq := bleve.NewSearchRequestOptions(q, limit, offset, false)
	searchReq.Fields = []string{"path", "title", "description", "version", "doc_type"}
	searchReq.Highlight = bleve.NewHighlightWithStyle("html")
	searchReq.Highlight.AddField("body")
	searchReq.Highlight.AddField("title")
	searchReq.Highlight.AddField("description")

	searchResult, err := s.index.Search(searchReq)
	if err != nil {
		return nil, fmt.Errorf("search: %w", err)
	}

	var results []Result
	for _, hit := range searchResult.Hits {
		r := Result{
			Path:    getString(hit.Fields, "path"),
			Title:   getString(hit.Fields, "title"),
			Version: getString(hit.Fields, "version"),
			DocType: getString(hit.Fields, "doc_type"),
			Score:   hit.Score,
		}

		// Build snippet from highlights or description
		r.Snippet = buildSnippet(hit, getString(hit.Fields, "description"))

		results = append(results, r)
	}

	return results, nil
}

func buildQuery(req *SearchRequest) query.Query {
	// Create text query across searchable fields
	titleQuery := query.NewMatchQuery(req.Query)
	descQuery := query.NewMatchQuery(req.Query)
	headingsQuery := query.NewMatchQuery(req.Query)
	bodyQuery := query.NewMatchQuery(req.Query)

	textQuery := bleve.NewDisjunctionQuery(
		boostQuery(titleQuery, "title", 3.0),
		boostQuery(descQuery, "description", 2.0),
		boostQuery(headingsQuery, "headings", 1.5),
		bodyQuery,
	)

	// If no filters, return text query directly
	if req.Version == "" && req.DocType == DocTypeUnspecified && req.PathPrefix == "" {
		return textQuery
	}

	// Build boolean query with filters
	boolQuery := bleve.NewBooleanQuery()
	boolQuery.AddMust(textQuery)

	if req.Version != "" {
		versionQuery := bleve.NewTermQuery(req.Version)
		versionQuery.SetField("version")
		boolQuery.AddMust(versionQuery)
	}

	if req.DocType != DocTypeUnspecified {
		docTypeStr := docTypeToString(req.DocType)
		docTypeQuery := bleve.NewTermQuery(docTypeStr)
		docTypeQuery.SetField("doc_type")
		boolQuery.AddMust(docTypeQuery)
	}

	if req.PathPrefix != "" {
		prefixQuery := bleve.NewPrefixQuery(req.PathPrefix)
		prefixQuery.SetField("path")
		boolQuery.AddMust(prefixQuery)
	}

	return boolQuery
}

func boostQuery(q *query.MatchQuery, field string, boost float64) query.Query {
	q.SetField(field)
	q.SetBoost(boost)
	return q
}

func docTypeToString(dt DocType) string {
	switch dt {
	case DocTypeSaaS:
		return "saas"
	case DocTypeVersioned:
		return "versioned"
	default:
		return ""
	}
}

func getString(fields map[string]interface{}, key string) string {
	if v, ok := fields[key]; ok {
		if s, ok := v.(string); ok {
			return s
		}
	}
	return ""
}

func buildSnippet(hit *search.DocumentMatch, description string) string {
	// Try to get highlighted fragments
	var fragments []string

	if hit.Fragments != nil {
		for _, fieldFragments := range hit.Fragments {
			fragments = append(fragments, fieldFragments...)
		}
	}

	if len(fragments) > 0 {
		// Strip HTML tags from highlight and join
		snippet := strings.Join(fragments, " ... ")
		snippet = stripHTMLTags(snippet)
		if len(snippet) > 300 {
			snippet = snippet[:300] + "..."
		}
		return snippet
	}

	// Fall back to description
	if description != "" {
		if len(description) > 300 {
			return description[:300] + "..."
		}
		return description
	}

	return ""
}

func stripHTMLTags(s string) string {
	// Replace highlight markers with markdown bold
	s = strings.ReplaceAll(s, "<mark>", "**")
	s = strings.ReplaceAll(s, "</mark>", "**")

	// Decode HTML entities (e.g., &lt; → <, &gt; → >, &#34; → ")
	s = html.UnescapeString(s)

	return s
}
