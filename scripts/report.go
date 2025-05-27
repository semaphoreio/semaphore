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
	Title string
}

// File configuration
var files = map[string]FileConfig{
	"docker-scan-junit.xml":           {Title: "Docker Security Scan"},
	"dependency-scan.xml":             {Title: "Dependency Scan"},
	"gosec-junit.xml":                 {Title: "Gosec Security Scan"},
	"junit.xml":                       {Title: "Tests"},
	"results.xml":                     {Title: "Tests"},
	"out/results.xml":                 {Title: "Tests"},
	"test-results.xml":                {Title: "Tests"},
	"junit-report.xml":                {Title: "Tests"},
	"assets/results.xml":              {Title: "Tests"},
	"out/lint-js-junit-report.xml":    {Title: "Tests"},
	"out/compile-ts-junit-report.xml": {Title: "Tests"},
	"out/test-js-junit-report.xml":    {Title: "Tests"},
	"out/test-ex-junit-report.xml":    {Title: "Tests"},
}

func getEnvOrDefault(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}

func buildSuitePrefix() string {
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

	return block
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
			suitePrefix := buildSuitePrefix()

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
