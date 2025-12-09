---
description: Examples using Semaphore MCP Server
sidebar_position: 2
---

# MCP Usage Examples

Semaphore’s [MCP Server](./mcp-server) unlocks practical, low-friction AI assistance for CI/CD. With an AI agent already connected, you can ask natural questions and get immediate insights from your Semaphore projects. 

Below, we outline key use cases and examples for developers, each accompanied by example prompts, an explanation of what happens under the hood, and relevant technical details. These scenarios assume that you have MCP access enabled and an API token configured.

## Organization and Project Context Discovery

Quickly identify which Semaphore organizations and projects your AI agent can access. This is useful for setting context before deeper queries. The agent can also cache organization and project IDs for later use, saving you time.

Example prompts:

- List organizations you have access to
- Find the current project’s organization ID and project ID and save them in AGENTS.md

:::note Claude Users

Claude users can automate project and organization ID discovery with the following command. See [MCP Server configuration](./mcp-server#claude-code) for more information:

```shell title="Initialize project's CLAUDE.md"
/semaphore:mcp_setup (MCP) your-project-name your-semaphore-organization
```

:::

Under the hood, the MCP server will determine the user based on the provided API token and fetch organizations or projects that are accessible to that user. The response returns organization or project metadata (IDs, names, etc.). The AI agent then presents a list of organization or project names or IDs, and can optionally write these identifiers to a file for future reference.

```text title="Related API calls"
GET https://<your-org>.semaphoreci.com/api/v1alpha/projects
Authorization: Bearer <YOUR_API_TOKEN>
```

For instance, the MCP response might return a JSON array of projects in your organization.

```json title="Example API response"
[
  {"name": "hello-semaphore", "id": "proj-1234-..."},
  {"name": "dockerizing-ruby", "id": "proj-5678-..."},
  {"name": "golang-mathapp", "id": "proj-9012-..."}
]
```

The agent uses this data to confirm connectivity and context. With IDs known, subsequent commands (like triggering or inspecting pipelines) don’t require you to manually look up IDs, reducing friction.

## Pipeline Overview and Understanding

Get a high-level summary of what a given Semaphore pipeline does. This helps onboard to a new project or review pipeline structure without digging through YAML. The AI agent can describe the pipeline’s stages, jobs, and purpose in plain language.

The MCP server exposes pipeline queries that the agent uses to gather pipeline details. Typically, the agent will: 


1. Use `workflows_search` to find the most recent workflow for the project (often filtered to the main branch or a specific workflow).  
2. Call `pipelines_list` with that workflow’s ID to get the pipeline(s) in that run (usually one pipeline unless promotions are involved).  
3. Invoke `pipeline_jobs` for the pipeline to list all jobs (and their statuses) defined in that pipeline.


Example prompts:

- Describe what my pipeline does for this project on Semaphore

These MCP tools wrap Semaphore’s API endpoints. For example, listing a pipeline’s jobs (with details) corresponds to retrieving the pipeline in “detailed” mode via the API. The response includes the pipeline’s blocks and jobs. For instance:

```json title="Example API response"
"blocks": [
  {
    "name": "RSpec",
    "jobs": [
      {
        "name": "Push results - 2/11",
        "result": "PASSED",
        "job_id": "31094182-03bf-4e39-acfe-ed1058d7eb6c"
      }
    ]
  }
]
```

In the above example, a pipeline has a block named “RSpec” with a job that passed. The AI agent can interpret this structure and articulate a summary, e.g.: “This pipeline checks out the repo, runs the RSpec test suite, then pushes the test results.” It uses the job names and any metadata to infer each step’s purpose. (If the pipeline had multiple stages like *Build*, *Test*, *Deploy*, those job names would be listed similarly, giving the agent context to explain the CI workflow.)

## Troubleshooting Test Failures

When a test suite fails in CI, the MCP-enabled agent can pinpoint which tests or steps failed and why, sparing you from manual log digging. This use case provides a quick diagnosis of failing tests in the latest workflow.

The agent leverages MCP tools to identify the failing tests. It will typically:
- Use `workflows_search` with the project context to find recent workflows, and select the latest failed workflow (e.g., the most recent run where tests failed).  
- Call `pipelines_list` for that workflow to get pipeline details, then find the pipeline with a `"result": "FAILED"`.  
- Call `pipeline_jobs` on the failed pipeline to get all jobs and their results. From this, the agent identifies which job corresponds to the test suite (for example, a job named “Test” or “RSpec” with a failed result).  
- Use `jobs_logs` for the failing test job to fetch the log output/events.

Example prompts:
- Help me figure out why the most recent workflow failed its tests on Semaphore

The MCP server’s `jobs_logs` tool fetches the raw log events for the job. The response includes a stream of log entries (e.g., each command’s output and final status). For example, log events might show something like:

```json title="Job logs response"
{
  "event": "cmd_output",
  "timestamp": 1719979253,
  "output": "Failures:\n  1) User login returns token\n     Expected true to equal false\n\n"
}
{
  "event": "job_finished",
  "timestamp": 1719979260,
  "result": "failed"
}
```

(Above is a representative snippet – the actual format includes an array of events.) The agent will scan the cmd_output entries for error indicators. In this case, it finds a failing test assertion in the output. The final job_finished event confirms that the job result has failed. (The API returns a series of such events for the job.)

Using this data, the AI assistant can explain the problem: e.g., “The tests failed because an assertion in the User login spec expected true to equal false. It looks like the login function is returning the wrong value.” This saves the developer from manually searching logs for the failure point.

## Troubleshooting Build Failures

Identify why a build or CI job failed (e.g., compilation errors, dependency issues) using a conversational query. Instead of combing through logs, a developer can ask the agent to pinpoint the cause of a broken build.

Under the hood, this follows a pattern similar to test failure troubleshooting, tailored to build steps:

- The agent calls `workflows_search` to get the latest workflow (often the last run on the default branch or the workflow that includes the build)
- It then uses `pipelines_list` to retrieve pipelines in that workflow and finds which pipeline failed (e.g., the pipeline’s "result": "FAILED" in the metadata)
- Next, `pipeline_jobs` provides the list of jobs in the failing pipeline. The agent locates the failing job – for a build error, this could be a job named “Build” or similar, with a failed status
- The agent invokes `jobs_logs` for that job to fetch the build log output

Example prompts:
- Why did my build fail on Semaphore?

Using the log events, the AI looks for error messages. For a build failure, the output might contain compiler errors, missing package messages, or non-zero exit codes. For example, the logs might include lines like error: module not found: XYZ or a stack trace. The MCP log stream would show the commands and their outputs up until the failure. The final job_finished event will indicate a failed result, confirming the build job didn’t succeed.

With this information, the assistant can explain the cause. For instance: “The build failed because the compiler couldn’t find module XYZ. It looks like a missing dependency – perhaps you need to add XYZ to your project’s dependencies.” The AI may also suggest next steps or fixes if the context is clear (e.g., installing a package or correcting a config), since the MCP server provided the exact error output that triggered the failure.

## Retrieving Job Logs for Debugging

Sometimes you need to see the raw logs for a job (build, test, deploy, etc.) to troubleshoot or verify behavior. With the MCP Server, you can ask for a job’s logs directly, and the agent will fetch and display them or summarize as needed. This on-demand log access is faster than clicking through the CI UI.

The agent will locate the specified job and retrieve its logs via the MCP server:
- It uses `workflows_search` to get the latest workflow, then pipelines_list to find the relevant pipeline. From there, the agent uses pipeline_jobs to find the job named “build” (as requested).
- Once the job ID is identified, the agent calls the `jobs_logs` tool. This triggers a `GET /logs/<job_id>` API call behind the scenes, which streams the log events for that job.


Example prompts:
- Show me the logs for the build job in the latest workflow in Semaphore

The MCP server returns the job’s log as a structured series of events (each command’s start, output, and finish). For example, part of a log JSON might look like:
```json  title="Example response"
{ "event": "cmd_output", "timestamp": 1719979253, "output": "Exporting CI\n" }, 
{ "event": "cmd_output", "timestamp": 1719979253, "output": "Running build scripts...\n" }, 
{ "event": "cmd_output", "timestamp": 1719979260, "output": "Build succeeded!\n" }

```

Each `cmd_output` event contains a chunk of the log text (in order). The agent can either stream this output back to you or compile it into a readable format. In practice, the AI might present the logs as plain text. If the logs are lengthy, the agent could summarize them or highlight key sections (e.g., errors or warnings) per your prompt.

This use case is essentially an AI-driven `tail -f`` or log viewer: you ask in natural language, and the MCP integration retrieves the exact logs from Semaphore for your inspection. It’s especially handy for sharing specific logs or examining them in your chat/IDE without switching contexts.

## See also

- [MCP Server](./mcp-server)
- [Self-healing CI](./self-healing-ci)
- [Copilot Cloud Integration](./copilot-agent-cloud)


