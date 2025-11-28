package prompts

import (
	"context"
	"strings"
	"testing"

	"github.com/mark3labs/mcp-go/mcp"
)

func TestAgentSetupHandler(t *testing.T) {
	handler := agentSetupHandler()

	t.Run("returns valid prompt result without arguments", func(t *testing.T) {
		req := mcp.GetPromptRequest{
			Params: mcp.GetPromptParams{
				Name:      agentSetupPromptName,
				Arguments: nil,
			},
		}

		result, err := handler(context.Background(), req)
		if err != nil {
			t.Fatalf("unexpected error: %v", err)
		}

		if result == nil {
			t.Fatal("expected non-nil result")
		}

		if len(result.Messages) != 1 {
			t.Fatalf("expected 1 message, got %d", len(result.Messages))
		}

		msg := result.Messages[0]
		if msg.Role != mcp.RoleUser {
			t.Errorf("expected role 'user', got %q", msg.Role)
		}

		content, ok := msg.Content.(mcp.TextContent)
		if !ok {
			t.Fatalf("expected TextContent, got %T", msg.Content)
		}

		if !strings.Contains(content.Text, "Semaphore MCP Server Configuration") {
			t.Error("expected content to contain configuration header")
		}

		if !strings.Contains(content.Text, "get_test_results") {
			t.Error("expected content to mention get_test_results tool")
		}

		if !strings.Contains(content.Text, "Download Once, Analyze Locally") {
			t.Error("expected content to contain test results download guidance")
		}
	})

	t.Run("includes project name when provided", func(t *testing.T) {
		req := mcp.GetPromptRequest{
			Params: mcp.GetPromptParams{
				Name: agentSetupPromptName,
				Arguments: map[string]string{
					"project_name": "my-test-project",
				},
			},
		}

		result, err := handler(context.Background(), req)
		if err != nil {
			t.Fatalf("unexpected error: %v", err)
		}

		content := result.Messages[0].Content.(mcp.TextContent)
		if !strings.Contains(content.Text, "my-test-project") {
			t.Error("expected content to include project name")
		}
	})

	t.Run("includes organization name when provided", func(t *testing.T) {
		req := mcp.GetPromptRequest{
			Params: mcp.GetPromptParams{
				Name: agentSetupPromptName,
				Arguments: map[string]string{
					"organization_name": "my-org",
				},
			},
		}

		result, err := handler(context.Background(), req)
		if err != nil {
			t.Fatalf("unexpected error: %v", err)
		}

		content := result.Messages[0].Content.(mcp.TextContent)
		if !strings.Contains(content.Text, "my-org") {
			t.Error("expected content to include organization name")
		}
	})

	t.Run("includes both project and organization when provided", func(t *testing.T) {
		req := mcp.GetPromptRequest{
			Params: mcp.GetPromptParams{
				Name: agentSetupPromptName,
				Arguments: map[string]string{
					"project_name":      "backend-api",
					"organization_name": "acme-corp",
				},
			},
		}

		result, err := handler(context.Background(), req)
		if err != nil {
			t.Fatalf("unexpected error: %v", err)
		}

		content := result.Messages[0].Content.(mcp.TextContent)
		if !strings.Contains(content.Text, "backend-api") {
			t.Error("expected content to include project name")
		}
		if !strings.Contains(content.Text, "acme-corp") {
			t.Error("expected content to include organization name")
		}
	})
}

func TestGenerateAgentConfig(t *testing.T) {
	t.Run("contains essential sections", func(t *testing.T) {
		config := generateAgentConfig("", "")

		essentialSections := []string{
			"Initial Setup: Discover and Cache IDs",
			"Workflow for Debugging Failed Builds",
			"Test Results: Download Once, Analyze Locally",
			"Tool Usage Best Practices",
			"Available Tools Reference",
			"Caching Strategy Summary",
		}

		for _, section := range essentialSections {
			if !strings.Contains(config, section) {
				t.Errorf("expected config to contain section %q", section)
			}
		}
	})

	t.Run("contains tool references", func(t *testing.T) {
		config := generateAgentConfig("", "")

		tools := []string{
			"organizations_list",
			"projects_list",
			"projects_search",
			"workflows_search",
			"workflows_run",
			"workflows_rerun",
			"pipelines_list",
			"pipeline_jobs",
			"jobs_describe",
			"jobs_logs",
			"get_test_results",
		}

		for _, tool := range tools {
			if !strings.Contains(config, tool) {
				t.Errorf("expected config to mention tool %q", tool)
			}
		}
	})

	t.Run("contains test results download instruction", func(t *testing.T) {
		config := generateAgentConfig("", "")

		if !strings.Contains(config, "curl -s") {
			t.Error("expected config to contain curl download command")
		}

		if !strings.Contains(config, "/tmp/test-results.json") {
			t.Error("expected config to reference local temp file for test results")
		}
	})
}
