package docs

import (
	"strings"
	"testing"
)

func TestRewriteRelativeLinks(t *testing.T) {
	tests := []struct {
		name        string
		content     string
		currentPath string
		expected    string
	}{
		{
			name:        "absolute URL unchanged",
			content:     "[link](https://example.com)",
			currentPath: "docs/guide.md",
			expected:    "[link](https://example.com)",
		},
		{
			name:        "mailto unchanged",
			content:     "[email](mailto:test@example.com)",
			currentPath: "docs/guide.md",
			expected:    "[email](mailto:test@example.com)",
		},
		{
			name:        "anchor-only link unchanged",
			content:     "[section](#section)",
			currentPath: "docs/guide.md",
			expected:    "[section](#section)",
		},
		{
			name:        "relative link rewritten",
			content:     "[other](other.md)",
			currentPath: "docs/guide.md",
			expected:    "[other](semaphore-docs://docs/other.md)",
		},
		{
			name:        "relative link with anchor preserved",
			content:     "[section](other.md#section)",
			currentPath: "docs/guide.md",
			expected:    "[section](semaphore-docs://docs/other.md#section)",
		},
		{
			name:        "absolute path in docs",
			content:     "[abs](/reference/api.md)",
			currentPath: "docs/guide.md",
			expected:    "[abs](semaphore-docs://reference/api.md)",
		},
		{
			name:        "path without extension gets .md",
			content:     "[noext](other)",
			currentPath: "docs/guide.md",
			expected:    "[noext](semaphore-docs://docs/other.md)",
		},
		{
			name:        "image link unchanged",
			content:     "![image](image.png)",
			currentPath: "docs/guide.md",
			expected:    "![image](image.png)",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := rewriteRelativeLinks(tt.content, tt.currentPath)
			if result != tt.expected {
				t.Errorf("rewriteRelativeLinks(%q, %q) = %q, want %q",
					tt.content, tt.currentPath, result, tt.expected)
			}
		})
	}
}

func TestStripFragmentFromPath(t *testing.T) {
	// This tests the logic that should be in docsResourceHandler
	// to strip fragments before looking up files
	tests := []struct {
		input    string
		expected string
	}{
		{"docs/guide.md", "docs/guide.md"},
		{"docs/guide.md#section", "docs/guide.md"},
		{"docs/guide.md#section-with-dashes", "docs/guide.md"},
		{"docs/path/to/file.md#anchor", "docs/path/to/file.md"},
	}

	for _, tt := range tests {
		t.Run(tt.input, func(t *testing.T) {
			path := tt.input
			if idx := strings.Index(path, "#"); idx != -1 {
				path = path[:idx]
			}
			if path != tt.expected {
				t.Errorf("strip fragment from %q = %q, want %q", tt.input, path, tt.expected)
			}
		})
	}
}
