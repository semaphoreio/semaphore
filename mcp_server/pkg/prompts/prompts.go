package prompts

import (
	"context"

	"github.com/mark3labs/mcp-go/mcp"
	"github.com/mark3labs/mcp-go/server"
)

const (
	agentSetupPromptName = "semaphore_agent_setup"
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
		mcp.WithPromptDescription(`Generate configuration instructions for AI agents to optimally use the Semaphore MCP server.

This prompt returns a comprehensive guide that should be added to the project's AGENTS.md or CLAUDE.md file.
The guide includes:
- Organization and project discovery workflow
- Caching strategy for IDs to minimize API calls
- Test results analysis best practices (download once, analyze locally)
- Optimal tool usage patterns and workflows
- Error handling and troubleshooting guidance

Use this prompt once per project to establish the agent configuration.`),
		mcp.WithArgument("project_name",
			mcp.ArgumentDescription("Name of the project this configuration is for. Used to personalize the configuration file."),
		),
		mcp.WithArgument("organization_name",
			mcp.ArgumentDescription("Optional: If you already know the organization name, provide it to skip the discovery step."),
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
	projectNote := ""
	if projectName != "" {
		projectNote = "Project: " + projectName + "\n"
	}
	orgNote := ""
	if orgName != "" {
		orgNote = "Organization: " + orgName + "\n"
	}

	return `# Semaphore MCP Server Configuration for AI Agents

` + projectNote + orgNote + `
Add this content to your project's AGENTS.md or CLAUDE.md file to enable optimal interaction with Semaphore CI/CD through the MCP server.

---

## Semaphore CI/CD Integration

This project uses Semaphore CI/CD. The Semaphore MCP server provides tools to interact with pipelines, workflows, jobs, and test results.

### Initial Setup: Discover and Cache IDs

Before using Semaphore tools, you MUST discover and cache the organization and project IDs. This avoids repeated API calls and ensures consistent tool usage.

**Step 1: Discover Organization ID**

` + "```" + `
# Call organizations_list to find available organizations
organizations_list(limit=10, mode="summary")
` + "```" + `

Store the organization_id in a local cache file (e.g., ` + "`.semaphore/config.json`" + `):

` + "```json" + `
{
  "organization_id": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "organization_name": "your-org-name"
}
` + "```" + `

**Step 2: Discover Project ID**

` + "```" + `
# Use the organization_id to find projects
projects_list(organization_id="<org_id>", limit=50, mode="summary")

# Or search by name/repository
projects_search(organization_id="<org_id>", query="<project_name>")
` + "```" + `

Update the cache file:

` + "```json" + `
{
  "organization_id": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "organization_name": "your-org-name",
  "project_id": "yyyyyyyy-yyyy-yyyy-yyyy-yyyyyyyyyyyy",
  "project_name": "your-project-name"
}
` + "```" + `

**IMPORTANT**: Always use cached IDs in subsequent tool calls. Do NOT re-discover IDs for every operation.

---

### Workflow for Debugging Failed Builds

When investigating CI failures, follow this optimized workflow:

1. **Search for recent workflows**:
` + "```" + `
workflows_search(
  organization_id="<cached_org_id>",
  project_id="<cached_project_id>",
  branch="main",  # or specific branch
  limit=10
)
` + "```" + `

2. **List pipelines for the workflow**:
` + "```" + `
pipelines_list(
  organization_id="<cached_org_id>",
  workflow_id="<workflow_id_from_step_1>",
  limit=5
)
` + "```" + `

3. **Get jobs from the failing pipeline**:
` + "```" + `
pipeline_jobs(
  organization_id="<cached_org_id>",
  pipeline_id="<pipeline_id>",
  mode="detailed"
)
` + "```" + `

4. **Fetch job logs for failed jobs**:
` + "```" + `
jobs_logs(
  organization_id="<cached_org_id>",
  job_id="<job_id>",
  tail_lines=200
)
` + "```" + `

5. **Get test results (IMPORTANT: Download once and reuse)**:
` + "```" + `
# For job-level test results
get_test_results(scope="job", job_id="<job_id>")

# For pipeline-level aggregated results
get_test_results(scope="pipeline", pipeline_id="<pipeline_id>", workflow_id="<workflow_id>")
` + "```" + `

---

### Test Results: Download Once, Analyze Locally

**CRITICAL**: The ` + "`get_test_results`" + ` tool returns a **signed URL that expires quickly**. You MUST:

1. **Download the test results JSON file to a local temporary file immediately**:
` + "```bash" + `
curl -s "<signed_url>" -o /tmp/test-results.json
` + "```" + `

2. **Read and analyze the local file** for all subsequent analysis:
` + "```" + `
# Read the downloaded file
cat /tmp/test-results.json
` + "```" + `

3. **DO NOT call get_test_results repeatedly** - the URL will expire and you'll waste API calls.

The test results JSON contains:
- Failed test cases with file paths and line numbers
- Error messages and stack traces
- Test durations
- Suite-level summaries

Use the local file for all analysis, pattern matching, and report generation.

---

### Tool Usage Best Practices

#### Minimize API Calls
- Cache organization_id and project_id after initial discovery
- Use ` + "`mode=\"summary\"`" + ` unless you need detailed information
- Set appropriate ` + "`limit`" + ` values (don't fetch more than needed)
- Use ` + "`branch`" + ` and ` + "`requester`" + ` filters to narrow results

#### Error Handling
- If a tool returns "permission denied", verify the organization_id and project_id are correct
- If workflows/pipelines are not found, try increasing the ` + "`limit`" + ` or removing filters
- For scope mismatch errors, ensure workflow_id matches the pipeline's actual workflow

#### Common Patterns

**Find why a specific branch is failing:**
` + "```" + `
workflows_search(organization_id="...", project_id="...", branch="feature-x", limit=5)
# Then drill down into pipelines → jobs → logs
` + "```" + `

**Find your own recent workflows:**
` + "```" + `
workflows_search(organization_id="...", project_id="...", my_workflows_only=true, limit=10)
` + "```" + `

**Investigate a specific pipeline by ID:**
` + "```" + `
pipeline_jobs(organization_id="...", pipeline_id="<specific_id>", mode="detailed")
` + "```" + `

**Get comprehensive job information:**
` + "```" + `
jobs_describe(organization_id="...", job_id="<job_id>", mode="detailed")
` + "```" + `

---

### Triggering New Builds

**Run a new workflow:**
` + "```" + `
workflows_run(
  organization_id="<org_id>",
  project_id="<project_id>",
  reference="refs/heads/main"  # or specific branch/tag
)
` + "```" + `

**Rerun a failed workflow:**
` + "```" + `
workflows_rerun(
  organization_id="<org_id>",
  workflow_id="<workflow_id>"
)
` + "```" + `

---

### Available Tools Reference

| Tool | Purpose | Key Parameters |
|------|---------|----------------|
| ` + "`organizations_list`" + ` | List accessible organizations | limit, mode |
| ` + "`projects_list`" + ` | List projects in an org | organization_id, limit, mode |
| ` + "`projects_search`" + ` | Search projects by name/repo | organization_id, query |
| ` + "`workflows_search`" + ` | Find workflows for a project | organization_id, project_id, branch, limit |
| ` + "`workflows_run`" + ` | Trigger a new workflow | organization_id, project_id, reference |
| ` + "`workflows_rerun`" + ` | Rerun an existing workflow | organization_id, workflow_id |
| ` + "`pipelines_list`" + ` | List pipelines in a workflow | organization_id, workflow_id, limit |
| ` + "`pipeline_jobs`" + ` | List jobs in a pipeline | organization_id, pipeline_id, mode |
| ` + "`jobs_describe`" + ` | Get job details | organization_id, job_id, mode |
| ` + "`jobs_logs`" + ` | Fetch job output logs | organization_id, job_id, tail_lines |
| ` + "`get_test_results`" + ` | Get test results URL | scope (job/pipeline), job_id or pipeline_id+workflow_id |

---

### Caching Strategy Summary

1. **Always cache these after initial discovery:**
   - organization_id
   - project_id
   - organization_name (for reference)
   - project_name (for reference)

2. **Store in a local file** (e.g., ` + "`.semaphore/config.json`" + `)

3. **Read cached values** before making tool calls

4. **Re-discover only if:**
   - Cached file doesn't exist
   - Organization/project has been deleted or renamed
   - Permission errors occur with cached IDs

---

### Example Session: Debugging a Failed Build

` + "```" + `
# 1. Load cached IDs (or discover if not cached)
# Assume we have: org_id="abc123", project_id="def456"

# 2. Find recent failed workflows
workflows_search(organization_id="abc123", project_id="def456", limit=5)
# Returns workflow_id="wf-789"

# 3. Get pipelines for that workflow
pipelines_list(organization_id="abc123", workflow_id="wf-789")
# Returns pipeline_id="ppl-111" with result="failed"

# 4. Get jobs from the failed pipeline
pipeline_jobs(organization_id="abc123", pipeline_id="ppl-111", mode="detailed")
# Returns job_id="job-222" with result="failed"

# 5. Get job logs
jobs_logs(organization_id="abc123", job_id="job-222", tail_lines=100)
# Review logs for error details

# 6. Get test results and download locally
get_test_results(scope="job", job_id="job-222")
# Returns signed URL

# 7. Download test results
curl -s "<signed_url>" -o /tmp/test-results.json

# 8. Analyze local test results file
cat /tmp/test-results.json
# Parse and analyze failed tests locally
` + "```" + `

---

This configuration ensures efficient use of the Semaphore MCP server, minimizes API calls through caching, and provides a clear workflow for common CI/CD debugging tasks.
`
}
