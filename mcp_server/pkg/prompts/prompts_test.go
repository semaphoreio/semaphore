package prompts

import (
	"context"
	"strings"
	"testing"

	"github.com/mark3labs/mcp-go/mcp"
)

func TestAgentSetupHandler(t *testing.T) {
	handler := agentSetupHandler()

	t.Run("returns valid prompt result", func(t *testing.T) {
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

		_, ok := msg.Content.(mcp.TextContent)
		if !ok {
			t.Fatalf("expected TextContent, got %T", msg.Content)
		}
	})

	t.Run("includes provided arguments in output", func(t *testing.T) {
		req := mcp.GetPromptRequest{
			Params: mcp.GetPromptParams{
				Name: agentSetupPromptName,
				Arguments: map[string]string{
					"project_name":      "my-project",
					"organization_name": "my-org",
				},
			},
		}

		result, err := handler(context.Background(), req)
		if err != nil {
			t.Fatalf("unexpected error: %v", err)
		}

		content := result.Messages[0].Content.(mcp.TextContent)
		if !strings.Contains(content.Text, "my-project") {
			t.Error("expected content to include project name")
		}
		if !strings.Contains(content.Text, "my-org") {
			t.Error("expected content to include organization name")
		}
	})
}
