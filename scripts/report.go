package main

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"strconv"
)

type FileConfig struct {
	Title  string
	Prefix string
}

// File configuration
var files = map[string]FileConfig{
	"docker-scan-junit.xml":           {Title: "Docker Security Scan", Prefix: "security"},
	"dependency-scan.xml":             {Title: "Dependency Scan", Prefix: "security"},
	"gosec-junit.xml":                 {Title: "Gosec Security Scan", Prefix: "security"},
	"junit.xml":                       {Title: "Tests", Prefix: "unit"},
	"results.xml":                     {Title: "Tests", Prefix: "integration"},
	"out/results.xml":                 {Title: "Tests", Prefix: "build"},
	"test-results.xml":                {Title: "Tests", Prefix: "integration"},
	"junit-report.xml":                {Title: "Tests", Prefix: "unit"},
	"assets/results.xml":              {Title: "Tests", Prefix: "assets"},
	"out/lint-js-junit-report.xml":    {Title: "Tests", Prefix: "lint"},
	"out/compile-ts-junit-report.xml": {Title: "Tests", Prefix: "compile"},
	"out/test-js-junit-report.xml":    {Title: "Tests", Prefix: "js-unit"},
	"out/test-ex-junit-report.xml":    {Title: "Tests", Prefix: "extended"},
}

func getEnvOrDefault(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}

func buildSuitePrefix(filePrefix string) string {
	block := getEnvOrDefault("SEMAPHORE_BLOCK_NAME", "unknown-block")
	job := getEnvOrDefault("SEMAPHORE_JOB_NAME", "unknown-job")
	jobCountStr := getEnvOrDefault("SEMAPHORE_JOB_COUNT", "1")

	jobCount, err := strconv.Atoi(jobCountStr)
	if err != nil {
		jobCount = 1
	}

	// Handle parallel jobs: remove " - X/Y" suffix at the end
	if jobCount > 1 {
		re := regexp.MustCompile(` - \d+/\d+$`)
		job = re.ReplaceAllString(job, "")
	}

	return fmt.Sprintf("%s/%s/%s", block, job, filePrefix)
}

func fileExists(filename string) bool {
	_, err := os.Stat(filename)
	return !os.IsNotExist(err)
}

func publishFile(filePath, title, suitePrefix string) error {
	cmd := exec.Command("test-results", "publish", "--name", title, "--suite-prefix", suitePrefix, filePath)
	return cmd.Run()
}

func main() {
	basePath := "."
	if len(os.Args) > 1 {
		basePath = os.Args[1]
	}

	published := 0

	fmt.Printf("Publishing test results from: %s\n\n", basePath)

	for filePath, config := range files {
		fullPath := filepath.Join(basePath, filePath)

		if fileExists(fullPath) {
			suitePrefix := buildSuitePrefix(config.Prefix)

			fmt.Printf("Found: %s (Title: '%s', Prefix: '%s')\n", fullPath, config.Title, suitePrefix)

			if err := publishFile(fullPath, config.Title, suitePrefix); err != nil {
				fmt.Printf("✗ Failed to publish: %s\n", fullPath)
			} else {
				fmt.Printf("✓ Successfully published: %s\n", fullPath)
				published++
			}
			fmt.Println()
		} else {
			fmt.Printf("Not found: %s\n", fullPath)
		}
	}

	fmt.Printf("Summary: Published %d test result files\n", published)

	if published == 0 {
		os.Exit(1)
	}
}
