package main

import (
	"flag"
	"fmt"
	"log"
	"os"

	"github.com/semaphoreio/semaphore/mcp_server/pkg/docssearch/indexer"
	"github.com/semaphoreio/semaphore/mcp_server/pkg/docssearch/loader"
)

func main() {
	docsRoot := flag.String("docs", "../docs", "Path to docs directory")
	outputPath := flag.String("output", "./index", "Path for output index")
	flag.Parse()

	// Remove existing index if present
	if _, err := os.Stat(*outputPath); err == nil {
		log.Printf("Removing existing index at %s", *outputPath)
		if err := os.RemoveAll(*outputPath); err != nil {
			log.Fatalf("Failed to remove existing index: %v", err)
		}
	}

	log.Printf("Loading docs from %s", *docsRoot)
	l := loader.New(*docsRoot)
	docs, err := l.LoadAll()
	if err != nil {
		log.Fatalf("Failed to load docs: %v", err)
	}
	log.Printf("Loaded %d documents", len(docs))

	// Print some stats
	versionCounts := make(map[string]int)
	docTypeCounts := make(map[string]int)
	for _, d := range docs {
		versionCounts[d.Version]++
		docTypeCounts[d.DocType]++
	}
	fmt.Println("\nDocuments by version:")
	for v, c := range versionCounts {
		fmt.Printf("  %s: %d\n", v, c)
	}
	fmt.Println("\nDocuments by type:")
	for t, c := range docTypeCounts {
		fmt.Printf("  %s: %d\n", t, c)
	}
	fmt.Println()

	log.Printf("Building index at %s", *outputPath)
	idx := indexer.New(*outputPath)
	if err := idx.BuildIndex(docs); err != nil {
		log.Fatalf("Failed to build index: %v", err)
	}

	log.Printf("Index built successfully with %d documents", len(docs))
}
