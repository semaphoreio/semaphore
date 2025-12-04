package loader

import (
	"bufio"
	"os"
	"path/filepath"
	"regexp"
	"strings"

	"gopkg.in/yaml.v3"
)

// Document represents a parsed documentation file.
type Document struct {
	Path        string   // relative path from docs root
	Title       string   // extracted from markdown h1
	Body        string   // markdown content (front matter stripped)
	Description string   // from front matter
	Version     string   // "saas", "CE", "EE", etc.
	DocType     string   // "saas" or "versioned"
	Headings    []string // h2/h3 headings for better search
}

// FrontMatter represents YAML front matter in docs.
type FrontMatter struct {
	Description string `yaml:"description"`
	Title       string `yaml:"title"`
}

var (
	headingH1Re = regexp.MustCompile(`^#\s+(.+)$`)
	headingH2Re = regexp.MustCompile(`^##\s+(.+)$`)
	headingH3Re = regexp.MustCompile(`^###\s+(.+)$`)
	// Matches self-closing JSX/MDX components: <Component ... />
	jsxSelfClosingRe = regexp.MustCompile(`<[A-Z][a-zA-Z]*[^>]*/\s*>`)
	// Matches opening JSX tag: <Component or <Component ...>
	jsxOpenTagRe = regexp.MustCompile(`<([A-Z][a-zA-Z]*)(?:\s[^>]*)?>`)
)

// Loader walks the docs directory and parses markdown files.
type Loader struct {
	docsRoot string
}

// New creates a new Loader for the given docs root directory.
func New(docsRoot string) *Loader {
	return &Loader{docsRoot: docsRoot}
}

// LoadAll walks the docs directory and returns all parsed documents.
func (l *Loader) LoadAll() ([]Document, error) {
	var docs []Document

	// Load SaaS docs from docs/docs/
	saasPath := filepath.Join(l.docsRoot, "docs")
	saasDocs, err := l.loadFromPath(saasPath, "saas", "saas")
	if err != nil {
		return nil, err
	}
	docs = append(docs, saasDocs...)

	// Load versioned docs from docs/versioned_docs/version-*
	versionedPath := filepath.Join(l.docsRoot, "versioned_docs")
	entries, err := os.ReadDir(versionedPath)
	if err != nil {
		// versioned_docs might not exist
		if os.IsNotExist(err) {
			return docs, nil
		}
		return nil, err
	}

	for _, entry := range entries {
		if !entry.IsDir() {
			continue
		}
		name := entry.Name()
		if !strings.HasPrefix(name, "version-") {
			continue
		}
		version := strings.TrimPrefix(name, "version-")
		vPath := filepath.Join(versionedPath, name)
		vDocs, err := l.loadFromPath(vPath, version, "versioned")
		if err != nil {
			return nil, err
		}
		docs = append(docs, vDocs...)
	}

	return docs, nil
}

func (l *Loader) loadFromPath(basePath, version, docType string) ([]Document, error) {
	var docs []Document

	err := filepath.Walk(basePath, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}
		if info.IsDir() {
			return nil
		}
		if !strings.HasSuffix(path, ".md") {
			return nil
		}

		doc, err := l.parseFile(path, version, docType)
		if err != nil {
			// Log and skip malformed files
			return nil
		}
		if doc != nil {
			docs = append(docs, *doc)
		}
		return nil
	})

	return docs, err
}

func (l *Loader) parseFile(path, version, docType string) (*Document, error) {
	content, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}

	relPath, err := filepath.Rel(l.docsRoot, path)
	if err != nil {
		relPath = path
	}

	body, frontMatter := parseFrontMatter(string(content))
	title := extractTitle(body, frontMatter)
	headings := extractHeadings(body)

	// Strip JSX/MDX components for cleaner search snippets
	cleanBody := stripJSXComponents(body)

	return &Document{
		Path:        relPath,
		Title:       title,
		Body:        cleanBody,
		Description: frontMatter.Description,
		Version:     version,
		DocType:     docType,
		Headings:    headings,
	}, nil
}

func parseFrontMatter(content string) (body string, fm FrontMatter) {
	lines := strings.Split(content, "\n")
	if len(lines) < 3 || strings.TrimSpace(lines[0]) != "---" {
		return content, fm
	}

	endIdx := -1
	for i := 1; i < len(lines); i++ {
		if strings.TrimSpace(lines[i]) == "---" {
			endIdx = i
			break
		}
	}

	if endIdx == -1 {
		return content, fm
	}

	fmContent := strings.Join(lines[1:endIdx], "\n")
	_ = yaml.Unmarshal([]byte(fmContent), &fm)

	body = strings.Join(lines[endIdx+1:], "\n")
	return strings.TrimSpace(body), fm
}

func extractTitle(body string, fm FrontMatter) string {
	// Try front matter title first
	if fm.Title != "" {
		return fm.Title
	}

	// Extract from first h1
	scanner := bufio.NewScanner(strings.NewReader(body))
	for scanner.Scan() {
		line := scanner.Text()
		if matches := headingH1Re.FindStringSubmatch(line); len(matches) > 1 {
			return strings.TrimSpace(matches[1])
		}
	}

	return ""
}

func extractHeadings(body string) []string {
	var headings []string
	scanner := bufio.NewScanner(strings.NewReader(body))
	for scanner.Scan() {
		line := scanner.Text()
		if matches := headingH2Re.FindStringSubmatch(line); len(matches) > 1 {
			headings = append(headings, strings.TrimSpace(matches[1]))
		} else if matches := headingH3Re.FindStringSubmatch(line); len(matches) > 1 {
			headings = append(headings, strings.TrimSpace(matches[1]))
		}
	}
	return headings
}

// stripJSXComponents removes JSX/MDX components from markdown content.
// This cleans up components like <VideoTutorial />, <Tabs>...</Tabs>, etc.
func stripJSXComponents(body string) string {
	// Remove self-closing components first: <Component ... />
	body = jsxSelfClosingRe.ReplaceAllString(body, "")

	// Remove paired components: <Component>...</Component>
	// Go's regexp doesn't support backreferences, so we find and remove manually
	for i := 0; i < 10; i++ {
		match := jsxOpenTagRe.FindStringSubmatchIndex(body)
		if match == nil {
			break
		}

		tagName := body[match[2]:match[3]]
		openStart := match[0]
		openEnd := match[1]

		// Find matching closing tag
		closeTag := "</" + tagName + ">"
		closeIdx := strings.Index(body[openEnd:], closeTag)
		if closeIdx == -1 {
			// No closing tag found, just remove the opening tag
			body = body[:openStart] + body[openEnd:]
			continue
		}

		// Remove from open tag to end of close tag
		closeEnd := openEnd + closeIdx + len(closeTag)
		body = body[:openStart] + body[closeEnd:]
	}

	return body
}
