package echo

import (
	"context"

	"github.com/mark3labs/mcp-go/mcp"
	"github.com/mark3labs/mcp-go/server"
)

const (
	ToolName        = "echo"
	toolDescription = "Echo back the provided message verbatim."
)

// Register wires the echo tool into the provided MCP server.
func Register(s *server.MCPServer) {
	s.AddTool(newTool(), handler)
}

func newTool() mcp.Tool {
	return mcp.NewTool(
		ToolName,
		mcp.WithDescription(toolDescription),
		mcp.WithString(
			"message",
			mcp.Required(),
			mcp.Description("The message to echo."),
		),
	)
}

func handler(_ context.Context, request mcp.CallToolRequest) (*mcp.CallToolResult, error) {
	message, err := request.RequireString("message")
	if err != nil {
		return mcp.NewToolResultError(err.Error()), nil
	}
	return mcp.NewToolResultText(message), nil
}
