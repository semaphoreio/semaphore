package prompts

import (
	"context"

	"github.com/mark3labs/mcp-go/mcp"
	"github.com/mark3labs/mcp-go/server"
)

const (
	agentSetupPromptName = "mcp_setup"
)

// Register wires all prompts into the MCP server.
func Register(s *server.MCPServer) {
	if s == nil {
		return
	}

	s.AddPrompt(newAgentSetupPrompt(), agentSetupHandler())
}

func newAgentSetupPrompt() mcp.Prompt {
	return mcp.NewPrompt(
		agentSetupPromptName,
		mcp.WithPromptDescription(`Generate Semaphore MCP configuration for AI agents.

Returns instructions to create:
1. .semaphore/MCP.md - Detailed usage guide (workflows, best practices)
2. A brief section to add to AGENTS.md or CLAUDE.md that references the MCP.md file

Use this prompt once per project to establish agent configuration.`),
		mcp.WithArgument("project_name",
			mcp.ArgumentDescription("Name of the project. Used to personalize the configuration."),
		),
		mcp.WithArgument("organization_name",
			mcp.ArgumentDescription("Optional: Organization name if already known."),
		),
	)
}

func agentSetupHandler() server.PromptHandlerFunc {
	return func(ctx context.Context, request mcp.GetPromptRequest) (*mcp.GetPromptResult, error) {
		projectName := ""
		if args := request.Params.Arguments; args != nil {
			if name, exists := args["project_name"]; exists {
				projectName = name
			}
		}
		orgName := ""
		if args := request.Params.Arguments; args != nil {
			if name, exists := args["organization_name"]; exists {
				orgName = name
			}
		}

		configContent := generateAgentConfig(projectName, orgName)

		return mcp.NewGetPromptResult(
			"Semaphore MCP Agent Configuration",
			[]mcp.PromptMessage{
				{
					Role: mcp.RoleUser,
					Content: mcp.TextContent{
						Type: "text",
						Text: configContent,
					},
				},
			},
		), nil
	}
}

func generateAgentConfig(projectName, orgName string) string {
	projectPlaceholder := "<project_name>"
	orgPlaceholder := "<organization_name>"
	if projectName != "" {
		projectPlaceholder = projectName
	}
	if orgName != "" {
		orgPlaceholder = orgName
	}

	return `# Semaphore MCP Setup

Create these files to configure Semaphore CI/CD integration:

## File 1: .semaphore/MCP.md

` + "```markdown" + `
# Semaphore CI/CD

## ID Caching (Required)

Before using Semaphore tools, cache org and project IDs in ` + "`.semaphore/config.json`" + `:

` + "```" + `json
{
  "organization_id": "<uuid>",
  "organization_name": "` + orgPlaceholder + `",
  "project_id": "<uuid>",
  "project_name": "` + projectPlaceholder + `"
}
` + "```" + `

Discover IDs once with ` + "`organizations_list`" + ` and ` + "`projects_list`" + `, then always use cached values.

## Debugging Workflow

1. ` + "`workflows_search`" + ` → find failing workflow
2. ` + "`pipelines_list`" + ` → get pipeline from workflow
3. ` + "`pipeline_jobs`" + ` → find failed jobs and check ` + "`result_reason`" + `
4. If ` + "`result_reason=test`" + `: use ` + "`get_test_results`" + ` first (structured failure data), fall back to ` + "`jobs_logs`" + ` only if no test results
5. Otherwise: use ` + "`jobs_logs`" + ` → read error output

## Test Results

` + "`get_test_results`" + ` returns a signed URL that **expires quickly**.

**Always:** Download once, analyze locally:
` + "```" + `bash
curl -s "<url>" -o /tmp/test-results.json
` + "```" + `

**Never:** Call get_test_results repeatedly.

## Tips

- Use ` + "`mode=\"summary\"`" + ` to reduce response size
- Filter with ` + "`branch`" + ` and ` + "`limit`" + ` parameters
- Read ` + "`.semaphore/config.json`" + ` before each session
` + "```" + `

## File 2: Add to CLAUDE.md (or AGENTS.md)

` + "```markdown" + `
## Semaphore CI/CD

See [.semaphore/MCP.md](.semaphore/MCP.md) for Semaphore tool usage.

Key rules:
- Cache org/project IDs in ` + "`.semaphore/config.json`" + `
- Download test results once (URLs expire)
- Use ` + "`mode=\"summary\"`" + ` to reduce API calls
` + "```" + `
`
}
