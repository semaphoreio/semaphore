package loader

import (
	"os"
	"path/filepath"
	"testing"
)

func TestParseFrontMatter(t *testing.T) {
	tests := []struct {
		name            string
		content         string
		wantBody        string
		wantDescription string
		wantTitle       string
	}{
		{
			name: "with front matter",
			content: `---
description: This is a test doc
title: Test Title
---

# Heading

Body content here.`,
			wantBody:        "# Heading\n\nBody content here.",
			wantDescription: "This is a test doc",
			wantTitle:       "Test Title",
		},
		{
			name: "no front matter",
			content: `# Just a Heading

Some content.`,
			wantBody:        "# Just a Heading\n\nSome content.",
			wantDescription: "",
			wantTitle:       "",
		},
		{
			name: "empty front matter",
			content: `---
---

# Empty FM

Content.`,
			wantBody:        "# Empty FM\n\nContent.",
			wantDescription: "",
			wantTitle:       "",
		},
		{
			name:            "unclosed front matter",
			content:         "---\ndescription: test\n# No closing",
			wantBody:        "---\ndescription: test\n# No closing",
			wantDescription: "",
			wantTitle:       "",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			body, fm := parseFrontMatter(tt.content)
			if body != tt.wantBody {
				t.Errorf("body = %q, want %q", body, tt.wantBody)
			}
			if fm.Description != tt.wantDescription {
				t.Errorf("description = %q, want %q", fm.Description, tt.wantDescription)
			}
			if fm.Title != tt.wantTitle {
				t.Errorf("title = %q, want %q", fm.Title, tt.wantTitle)
			}
		})
	}
}

func TestExtractTitle(t *testing.T) {
	tests := []struct {
		name      string
		body      string
		fmTitle   string
		wantTitle string
	}{
		{
			name:      "title from h1",
			body:      "# My Document\n\nSome content",
			fmTitle:   "",
			wantTitle: "My Document",
		},
		{
			name:      "title from front matter takes precedence",
			body:      "# Body Title\n\nContent",
			fmTitle:   "FM Title",
			wantTitle: "FM Title",
		},
		{
			name:      "no title",
			body:      "Just some text without heading",
			fmTitle:   "",
			wantTitle: "",
		},
		{
			name:      "h2 not picked as title",
			body:      "## Second Level\n\nContent",
			fmTitle:   "",
			wantTitle: "",
		},
		{
			name:      "title with extra spaces",
			body:      "#   Spaced Title  \n\nContent",
			fmTitle:   "",
			wantTitle: "Spaced Title",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			fm := FrontMatter{Title: tt.fmTitle}
			got := extractTitle(tt.body, fm)
			if got != tt.wantTitle {
				t.Errorf("extractTitle() = %q, want %q", got, tt.wantTitle)
			}
		})
	}
}

func TestExtractHeadings(t *testing.T) {
	body := `# Main Title

## First Section

Some content.

### Subsection

More content.

## Second Section

Final content.

#### Too deep - not included
`
	headings := extractHeadings(body)

	want := []string{"First Section", "Subsection", "Second Section"}
	if len(headings) != len(want) {
		t.Fatalf("got %d headings, want %d", len(headings), len(want))
	}
	for i, h := range headings {
		if h != want[i] {
			t.Errorf("heading[%d] = %q, want %q", i, h, want[i])
		}
	}
}

func TestStripJSXComponents(t *testing.T) {
	tests := []struct {
		name  string
		input string
		want  string
	}{
		{
			name: "self-closing component",
			input: `# Title

<VideoTutorial src="test" />

Some content.`,
			want: `# Title



Some content.`,
		},
		{
			name: "paired component",
			input: `# Title

<Tabs>
content inside tabs
</Tabs>

After tabs.`,
			want: `# Title



After tabs.`,
		},
		{
			name: "nested components",
			input: `<Tabs groupId="test">
<TabItem value="a" label="A">
Content A
</TabItem>
<TabItem value="b" label="B">
Content B
</TabItem>
</Tabs>`,
			want: ``,
		},
		{
			name:  "no components",
			input: "Just plain markdown\n\nWith paragraphs.",
			want:  "Just plain markdown\n\nWith paragraphs.",
		},
		{
			name:  "mixed content",
			input: "Start\n<Component />\nMiddle\n<Wrapper>inner</Wrapper>\nEnd",
			want:  "Start\n\nMiddle\n\nEnd",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := stripJSXComponents(tt.input)
			if got != tt.want {
				t.Errorf("stripJSXComponents() = %q, want %q", got, tt.want)
			}
		})
	}
}

func TestLoaderLoadAll(t *testing.T) {
	// Create temp directory structure
	tmpDir, err := os.MkdirTemp("", "docssearch-test")
	if err != nil {
		t.Fatal(err)
	}
	defer os.RemoveAll(tmpDir)

	// Create docs/docs structure (SaaS)
	saasDir := filepath.Join(tmpDir, "docs")
	if err := os.MkdirAll(saasDir, 0755); err != nil {
		t.Fatal(err)
	}

	saasDoc := `---
description: SaaS doc description
---

# SaaS Document

Content here.
`
	if err := os.WriteFile(filepath.Join(saasDir, "test.md"), []byte(saasDoc), 0644); err != nil {
		t.Fatal(err)
	}

	// Create versioned_docs structure
	versionedDir := filepath.Join(tmpDir, "versioned_docs", "version-CE")
	if err := os.MkdirAll(versionedDir, 0755); err != nil {
		t.Fatal(err)
	}

	versionedDoc := `---
description: CE doc description
---

# CE Document

CE content.
`
	if err := os.WriteFile(filepath.Join(versionedDir, "ce-doc.md"), []byte(versionedDoc), 0644); err != nil {
		t.Fatal(err)
	}

	// Load docs
	loader := New(tmpDir)
	docs, err := loader.LoadAll()
	if err != nil {
		t.Fatalf("LoadAll() error = %v", err)
	}

	if len(docs) != 2 {
		t.Fatalf("got %d docs, want 2", len(docs))
	}

	// Check SaaS doc
	var saas, ce *Document
	for i := range docs {
		if docs[i].DocType == "saas" {
			saas = &docs[i]
		} else if docs[i].Version == "CE" {
			ce = &docs[i]
		}
	}

	if saas == nil {
		t.Fatal("SaaS doc not found")
	}
	if saas.Title != "SaaS Document" {
		t.Errorf("SaaS title = %q, want %q", saas.Title, "SaaS Document")
	}
	if saas.Description != "SaaS doc description" {
		t.Errorf("SaaS description = %q, want %q", saas.Description, "SaaS doc description")
	}
	if saas.Version != "saas" {
		t.Errorf("SaaS version = %q, want %q", saas.Version, "saas")
	}

	if ce == nil {
		t.Fatal("CE doc not found")
	}
	if ce.Title != "CE Document" {
		t.Errorf("CE title = %q, want %q", ce.Title, "CE Document")
	}
	if ce.DocType != "versioned" {
		t.Errorf("CE docType = %q, want %q", ce.DocType, "versioned")
	}
}
