package indexer

import (
	"fmt"
	"strings"

	"github.com/blevesearch/bleve/v2"
	"github.com/blevesearch/bleve/v2/mapping"
	"github.com/semaphoreio/semaphore/mcp_server/pkg/docssearch/loader"
)

// IndexedDocument is the structure stored in Bleve index.
type IndexedDocument struct {
	Path        string `json:"path"`
	Title       string `json:"title"`
	Body        string `json:"body"`
	Description string `json:"description"`
	Version     string `json:"version"`
	DocType     string `json:"doc_type"`
	Headings    string `json:"headings"` // joined with newlines for full-text search
}

// Indexer creates and manages Bleve indexes.
type Indexer struct {
	indexPath string
}

// New creates a new Indexer that will write to the given path.
func New(indexPath string) *Indexer {
	return &Indexer{indexPath: indexPath}
}

// BuildIndex creates a new Bleve index from the given documents.
func (i *Indexer) BuildIndex(docs []loader.Document) error {
	m := newIndexMapping()

	index, err := bleve.New(i.indexPath, m)
	if err != nil {
		return fmt.Errorf("create index: %w", err)
	}
	defer index.Close()

	batch := index.NewBatch()
	for _, doc := range docs {
		idoc := IndexedDocument{
			Path:        doc.Path,
			Title:       doc.Title,
			Body:        doc.Body,
			Description: doc.Description,
			Version:     doc.Version,
			DocType:     doc.DocType,
			Headings:    strings.Join(doc.Headings, "\n"),
		}
		if err := batch.Index(doc.Path, idoc); err != nil {
			return fmt.Errorf("index document %s: %w", doc.Path, err)
		}
	}

	if err := index.Batch(batch); err != nil {
		return fmt.Errorf("batch index: %w", err)
	}

	return nil
}

func newIndexMapping() mapping.IndexMapping {
	// Create field mappings
	textFieldMapping := bleve.NewTextFieldMapping()
	textFieldMapping.Store = true
	textFieldMapping.IncludeTermVectors = true

	keywordFieldMapping := bleve.NewKeywordFieldMapping()
	keywordFieldMapping.Store = true

	// Title with boost
	titleFieldMapping := bleve.NewTextFieldMapping()
	titleFieldMapping.Store = true
	titleFieldMapping.IncludeTermVectors = true

	// Description with boost
	descFieldMapping := bleve.NewTextFieldMapping()
	descFieldMapping.Store = true
	descFieldMapping.IncludeTermVectors = true

	// Create document mapping
	docMapping := bleve.NewDocumentMapping()
	docMapping.AddFieldMappingsAt("path", keywordFieldMapping)
	docMapping.AddFieldMappingsAt("title", titleFieldMapping)
	docMapping.AddFieldMappingsAt("body", textFieldMapping)
	docMapping.AddFieldMappingsAt("description", descFieldMapping)
	docMapping.AddFieldMappingsAt("version", keywordFieldMapping)
	docMapping.AddFieldMappingsAt("doc_type", keywordFieldMapping)
	docMapping.AddFieldMappingsAt("headings", textFieldMapping)

	// Create index mapping
	indexMapping := bleve.NewIndexMapping()
	indexMapping.DefaultMapping = docMapping
	indexMapping.DefaultAnalyzer = "en"

	return indexMapping
}
