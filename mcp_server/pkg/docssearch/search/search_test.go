package search

import (
	"os"
	"path/filepath"
	"testing"

	blevesearch "github.com/blevesearch/bleve/v2/search"
	"github.com/semaphoreio/semaphore/mcp_server/pkg/docssearch/indexer"
	"github.com/semaphoreio/semaphore/mcp_server/pkg/docssearch/loader"
)

func TestDocTypeToString(t *testing.T) {
	tests := []struct {
		input DocType
		want  string
	}{
		{DocTypeSaaS, "saas"},
		{DocTypeVersioned, "versioned"},
		{DocTypeUnspecified, ""},
	}

	for _, tt := range tests {
		got := docTypeToString(tt.input)
		if got != tt.want {
			t.Errorf("docTypeToString(%v) = %q, want %q", tt.input, got, tt.want)
		}
	}
}

func TestGetString(t *testing.T) {
	fields := map[string]interface{}{
		"title":   "Test Title",
		"count":   42,
		"version": "saas",
	}

	tests := []struct {
		key  string
		want string
	}{
		{"title", "Test Title"},
		{"version", "saas"},
		{"missing", ""},
		{"count", ""}, // not a string
	}

	for _, tt := range tests {
		got := getString(fields, tt.key)
		if got != tt.want {
			t.Errorf("getString(%q) = %q, want %q", tt.key, got, tt.want)
		}
	}
}

func TestStripHTMLTags(t *testing.T) {
	tests := []struct {
		input string
		want  string
	}{
		{"<mark>highlighted</mark>", "**highlighted**"},
		{"no tags here", "no tags here"},
		{"<mark>one</mark> and <mark>two</mark>", "**one** and **two**"},
		{"", ""},
		// HTML entity decoding
		{"&lt;div&gt;content&lt;/div&gt;", "<div>content</div>"},
		{"&#34;quoted&#34;", `"quoted"`},
		{"&amp; ampersand", "& ampersand"},
		{"<mark>&lt;Component /&gt;</mark>", "**<Component />**"},
	}

	for _, tt := range tests {
		got := stripHTMLTags(tt.input)
		if got != tt.want {
			t.Errorf("stripHTMLTags(%q) = %q, want %q", tt.input, got, tt.want)
		}
	}
}

func TestBuildSnippet(t *testing.T) {
	t.Run("with fragments", func(t *testing.T) {
		hit := &blevesearch.DocumentMatch{
			Fragments: map[string][]string{
				"body": {"fragment <mark>one</mark>", "fragment <mark>two</mark>"},
			},
		}
		got := buildSnippet(hit, "fallback description")
		want := "fragment **one** ... fragment **two**"
		if got != want {
			t.Errorf("buildSnippet() = %q, want %q", got, want)
		}
	})

	t.Run("fallback to description", func(t *testing.T) {
		hit := &blevesearch.DocumentMatch{}
		got := buildSnippet(hit, "fallback description")
		if got != "fallback description" {
			t.Errorf("buildSnippet() = %q, want %q", got, "fallback description")
		}
	})

	t.Run("truncate long description", func(t *testing.T) {
		hit := &blevesearch.DocumentMatch{}
		longDesc := string(make([]byte, 400))
		for i := range longDesc {
			longDesc = longDesc[:i] + "x" + longDesc[i+1:]
		}
		got := buildSnippet(hit, longDesc)
		if len(got) != 303 { // 300 + "..."
			t.Errorf("buildSnippet() len = %d, want 303", len(got))
		}
	})

	t.Run("empty", func(t *testing.T) {
		hit := &blevesearch.DocumentMatch{}
		got := buildSnippet(hit, "")
		if got != "" {
			t.Errorf("buildSnippet() = %q, want empty", got)
		}
	})
}

func TestSearchIntegration(t *testing.T) {
	// Create temp directory for index
	tmpDir, err := os.MkdirTemp("", "docssearch-test")
	if err != nil {
		t.Fatal(err)
	}
	defer os.RemoveAll(tmpDir)

	indexPath := filepath.Join(tmpDir, "index")

	// Create test documents
	docs := []loader.Document{
		{
			Path:        "docs/getting-started/quickstart.md",
			Title:       "Quickstart Guide",
			Body:        "Learn how to set up your first pipeline quickly.",
			Description: "Get started with Semaphore in minutes",
			Version:     "saas",
			DocType:     "saas",
			Headings:    []string{"Prerequisites", "Step 1", "Step 2"},
		},
		{
			Path:        "docs/reference/pipeline-yaml.md",
			Title:       "Pipeline YAML Reference",
			Body:        "Complete reference for pipeline configuration.",
			Description: "Pipeline YAML syntax and options",
			Version:     "saas",
			DocType:     "saas",
			Headings:    []string{"Syntax", "Examples"},
		},
		{
			Path:        "versioned_docs/version-CE/getting-started/install.md",
			Title:       "Installation Guide",
			Body:        "How to install Semaphore CE on your infrastructure.",
			Description: "Install Semaphore Community Edition",
			Version:     "CE",
			DocType:     "versioned",
			Headings:    []string{"Requirements", "Docker", "Kubernetes"},
		},
	}

	// Build index
	idx := indexer.New(indexPath)
	if err := idx.BuildIndex(docs); err != nil {
		t.Fatalf("BuildIndex() error = %v", err)
	}

	// Open searcher
	searcher, err := Open(indexPath)
	if err != nil {
		t.Fatalf("Open() error = %v", err)
	}
	defer searcher.Close()

	t.Run("basic search", func(t *testing.T) {
		req := &SearchRequest{
			Query: "pipeline",
			Limit: 10,
		}
		results, err := searcher.Search(req)
		if err != nil {
			t.Fatalf("Search() error = %v", err)
		}
		if len(results) == 0 {
			t.Error("Search() returned no results")
		}
		// Pipeline YAML Reference should be in results
		found := false
		for _, r := range results {
			if r.Title == "Pipeline YAML Reference" {
				found = true
				break
			}
		}
		if !found {
			t.Error("Expected 'Pipeline YAML Reference' in results")
		}
	})

	t.Run("search with version filter", func(t *testing.T) {
		req := &SearchRequest{
			Query:   "install",
			Version: "CE",
			Limit:   10,
		}
		results, err := searcher.Search(req)
		if err != nil {
			t.Fatalf("Search() error = %v", err)
		}
		for _, r := range results {
			if r.Version != "CE" {
				t.Errorf("Result version = %q, want CE", r.Version)
			}
		}
	})

	t.Run("search with doc type filter", func(t *testing.T) {
		req := &SearchRequest{
			Query:   "guide",
			DocType: DocTypeSaaS,
			Limit:   10,
		}
		results, err := searcher.Search(req)
		if err != nil {
			t.Fatalf("Search() error = %v", err)
		}
		for _, r := range results {
			if r.DocType != "saas" {
				t.Errorf("Result doc_type = %q, want saas", r.DocType)
			}
		}
	})

	t.Run("search with path prefix filter", func(t *testing.T) {
		req := &SearchRequest{
			Query:      "guide",
			PathPrefix: "docs/getting-started",
			Limit:      10,
		}
		results, err := searcher.Search(req)
		if err != nil {
			t.Fatalf("Search() error = %v", err)
		}
		prefix := "docs/getting-started"
		for _, r := range results {
			if len(r.Path) < len(prefix) || r.Path[:len(prefix)] != prefix {
				t.Errorf("Result path = %q, expected prefix %s", r.Path, prefix)
			}
		}
	})

	t.Run("search with limit", func(t *testing.T) {
		req := &SearchRequest{
			Query: "semaphore",
			Limit: 1,
		}
		results, err := searcher.Search(req)
		if err != nil {
			t.Fatalf("Search() error = %v", err)
		}
		if len(results) > 1 {
			t.Errorf("Search() returned %d results, want <= 1", len(results))
		}
	})

	t.Run("no results", func(t *testing.T) {
		req := &SearchRequest{
			Query: "xyznonexistent",
			Limit: 10,
		}
		results, err := searcher.Search(req)
		if err != nil {
			t.Fatalf("Search() error = %v", err)
		}
		if len(results) != 0 {
			t.Errorf("Search() returned %d results, want 0", len(results))
		}
	})
}
