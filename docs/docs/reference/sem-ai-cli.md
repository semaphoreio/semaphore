---
description: sem-ai command line reference
---

# sem-ai Command Line

sem-ai is an agent-first CLI for Semaphore CI/CD. It's designed for AI agents and automation, with structured JSON output, self-discovery, and composable commands. It can also run as an MCP server for direct tool integration.

## Overview

sem-ai provides full control over your Semaphore CI/CD from the terminal or from AI agents. Every command returns structured JSON by default. Key capabilities:

- Diagnose CI failures with parsed test results
- Pipeline topology analysis (critical path, blast radius)
- Test intelligence (flaky detection, test summaries)
- Testbox: run commands in real CI environments before pushing
- MCP server mode for native AI agent integration

## Installation {#install}

### From source

```shell
git clone https://github.com/semaphoreci/sem-ai.git
cd sem-ai
make install
```

### Using Go

```shell
go install github.com/semaphoreci/sem-ai@latest
```

## Setup {#setup}

### sem-ai connect {#connect}

Connect to your Semaphore organization. You need an [API token](https://me.semaphoreci.com/account).

```shell
sem-ai connect <organization>.semaphoreci.com <API_TOKEN>
```

For example:

```shell
sem-ai connect myorg.semaphoreci.com NeUFkim46BCdpqCAyWXN
```

The token is stored in `~/.sem.yaml`, shared with the [Semaphore CLI](./semaphore-cli). If you already have `sem` configured, sem-ai uses the same credentials automatically.

### sem-ai context {#context}

List configured organizations:

```shell
sem-ai context list
```

Show the active organization:

```shell
sem-ai context show
```

## General syntax {#syntax}

```shell
sem-ai <command> [subcommand] [flags]
```

Global flags:

| Flag | Description |
|------|-------------|
| `--format` or `-f` | Output format: `json` (default), `table`, `yaml` |
| `--verbose` or `-v` | Show HTTP requests for debugging |
| `--examples` | Show usage examples for any command |
| `--help` or `-h` | Help for any command |

## Self-discovery {#discovery}

### sem-ai discover {#discover}

Returns a structured map of every command, its flags, and examples. Designed for AI agents to self-orient without documentation.

```shell
sem-ai discover
sem-ai discover --format table
```

### sem-ai \<command\> --examples {#examples}

Every command supports `--examples` to show usage examples:

```shell
sem-ai diagnose --examples
sem-ai pipeline promote --examples
```

## Working with projects {#projects}

### sem-ai project list {#project-list}

List all projects in the organization:

```shell
sem-ai project list
```

### sem-ai project show {#project-show}

Show project details:

```shell
sem-ai project show <project-name>
```

### sem-ai project update {#project-update}

Update project settings:

```shell
sem-ai project update <project-name> --visibility public
sem-ai project update <project-name> --description "My app"
```

### sem-ai project delete {#project-delete}

Delete a project:

```shell
sem-ai project delete <project-name>
```

## Working with workflows {#workflows}

### sem-ai workflow list {#workflow-list}

List workflows for a project:

```shell
sem-ai workflow list --project <project-name>
sem-ai workflow list --project <project-name> --branch main
```

### sem-ai workflow show {#workflow-show}

Show workflow details:

```shell
sem-ai workflow show <workflow-id>
```

### sem-ai workflow run {#workflow-run}

Trigger a new workflow run (reruns the latest workflow):

```shell
sem-ai workflow run --project <project-name>
sem-ai workflow run --project <project-name> --branch feature-x
```

### sem-ai workflow rerun {#workflow-rerun}

Rerun a specific workflow:

```shell
sem-ai workflow rerun <workflow-id>
```

### sem-ai workflow stop {#workflow-stop}

Stop a running workflow:

```shell
sem-ai workflow stop <workflow-id>
```

## Working with pipelines {#pipelines}

### sem-ai pipeline show {#pipeline-show}

Show pipeline with blocks and jobs tree:

```shell
sem-ai pipeline show <pipeline-id>
```

### sem-ai pipeline list {#pipeline-list}

List pipelines for a project:

```shell
sem-ai pipeline list --project <project-name>
```

### sem-ai pipeline stop {#pipeline-stop}

Stop a running pipeline:

```shell
sem-ai pipeline stop <pipeline-id>
```

### sem-ai pipeline rebuild {#pipeline-rebuild}

Rebuild only failed blocks (partial rebuild):

```shell
sem-ai pipeline rebuild <pipeline-id>
```

### sem-ai pipeline promote {#pipeline-promote}

Trigger a promotion (deployment). This is a safety-gated operation:

- Without `--confirm`: dry run showing what would happen
- With `--confirm`: actually executes the promotion

```shell
# Dry run
sem-ai pipeline promote <pipeline-id> --target "Deploy to Staging"

# Execute
sem-ai pipeline promote <pipeline-id> --target "Deploy to Staging" --confirm

# Override conditions (promote despite failures)
sem-ai pipeline promote <pipeline-id> --target "Deploy to Staging" --confirm --override

# With parameters
sem-ai pipeline promote <pipeline-id> --target "Production" --confirm --param version=1.2.3
```

### sem-ai pipeline topology {#pipeline-topology}

Show the block dependency graph:

```shell
sem-ai pipeline topology <pipeline-id>
```

## Working with jobs {#jobs}

### sem-ai job list {#job-list}

List jobs, optionally filtered by state:

```shell
sem-ai job list --states RUNNING --states QUEUED
sem-ai job list --states FINISHED
```

### sem-ai job show {#job-show}

Show job details:

```shell
sem-ai job show <job-id>
```

### sem-ai job log {#job-log}

Fetch structured job logs:

```shell
sem-ai job log <job-id>
sem-ai job log <job-id> --format table
```

### sem-ai job stop {#job-stop}

Stop a running job:

```shell
sem-ai job stop <job-id>
```

## Compound commands {#compound}

These commands compose multiple API calls into a single operation.

### sem-ai status {#status}

Quick CI status for a branch:

```shell
sem-ai status --project <project-name> --branch main
```

When run inside a git repository, project and branch are auto-detected:

```shell
sem-ai status
```

### sem-ai diagnose {#diagnose}

One-command failure diagnosis. Composes workflow lookup, pipeline details, failed jobs, log tails, and parsed test results into a single structured response.

```shell
sem-ai diagnose
sem-ai diagnose <workflow-id>
sem-ai diagnose --project <project-name> --branch main
```

Returns structured output with:
- Pipeline state and result
- Failed blocks and jobs
- Log tails with failed commands highlighted
- Parsed test results with file, line, and error message

### sem-ai health {#health}

Project health summary with pass rates, failure trends, and deployment status:

```shell
sem-ai health --project <project-name>
```

### sem-ai watch {#watch}

Poll a workflow until it completes, streaming status updates:

```shell
sem-ai watch <workflow-id>
sem-ai watch <workflow-id> --interval 10s
```

### sem-ai promote-and-wait {#promote-and-wait}

Promote a pipeline and block until the promoted pipeline finishes:

```shell
# Dry run
sem-ai promote-and-wait <pipeline-id> --target "Deploy to Staging"

# Execute and wait
sem-ai promote-and-wait <pipeline-id> --target "Deploy to Staging" --confirm
```

### sem-ai open {#open}

Open the latest workflow for the current branch in the browser:

```shell
sem-ai open
sem-ai open --project my-app
sem-ai open --workflow <workflow-id>
```

### sem-ai version {#version}

Print version information as JSON:

```shell
sem-ai version
```

### sem-ai rerun-failed {#rerun-failed}

Rebuild only failed blocks in a pipeline:

```shell
sem-ai rerun-failed <pipeline-id>
```

### sem-ai critical-path {#critical-path}

Show the longest dependency chain (bottleneck) in a pipeline:

```shell
sem-ai critical-path <pipeline-id>
```

### sem-ai blast-radius {#blast-radius}

Show which blocks failed as root causes vs which were canceled due to upstream failures:

```shell
sem-ai blast-radius <pipeline-id>
sem-ai blast-radius <pipeline-id> --block "Build"
```

## Analytics {#analytics}

Historical pipeline and workflow analytics. All analytics commands share a common set of flags:

| Flag | Default | Description |
|------|---------|-------------|
| `--project` | auto-detected | Project name |
| `--branch` | all branches | Filter by branch |
| `--days` | `7` | Time window in days |
| `--limit` | `100` | Max workflows to analyze |

### sem-ai analytics summary {#analytics-summary}

All-in-one analytics overview: pass rate, duration stats (avg/p50/p95), phase breakdown (compile, queue, execution), failing blocks, deploy count, and trigger distribution.

```shell
sem-ai analytics summary --project my-app
sem-ai analytics summary --project my-app --days 30 --branch main
```

### sem-ai analytics duration {#analytics-duration}

Pipeline duration trends with avg, p50, p95, min, and max, plus a phase breakdown showing where time is spent (compile, queue, execution).

```shell
sem-ai analytics duration --project my-app --days 30
```

### sem-ai analytics failures {#analytics-failures}

Block-level failure rates across analyzed pipelines, ranked by failure count. Also reports overall pass rate and failure reasons (test failure, stuck, canceled, etc.).

```shell
sem-ai analytics failures --project my-app --days 14
```

### sem-ai analytics queue {#analytics-queue}

Queue wait time analysis (avg, p50, p95, min, max) — measures time between a job being queued and starting execution.

```shell
sem-ai analytics queue --project my-app --days 7
```

### sem-ai analytics deploys {#analytics-deploys}

Deploy frequency and promotion stats: total deploys, deploys per day, and deploys per week.

```shell
sem-ai analytics deploys --project my-app --days 30
```

### sem-ai analytics trend {#analytics-trend}

Week-over-week trends for pass rate, duration, queue time, failure reasons, and trigger distribution. Uses `--weeks` instead of `--days`.

| Flag | Default | Description |
|------|---------|-------------|
| `--weeks` | `4` | Number of weeks to analyze |
| `--limit` | `200` | Max workflows to analyze |

```shell
sem-ai analytics trend --project my-app --weeks 4
sem-ai analytics trend --project my-app --weeks 8 --branch main
```

Returns an array of weekly buckets plus an overall `trend` field: `improving`, `degrading`, or `stable`.

## Test intelligence {#tests}

### sem-ai test summary {#test-summary}

AI-friendly test summary for a pipeline. Parses test results from job logs and artifacts.

```shell
sem-ai test summary --pipeline <pipeline-id>
```

### sem-ai test report {#test-report}

Detailed test results with individual test cases:

```shell
sem-ai test report --pipeline <pipeline-id>
```

### sem-ai test flaky {#test-flaky}

Detect flaky tests by analyzing recent workflow runs:

```shell
sem-ai test flaky --project <project-name>
sem-ai test flaky --project <project-name> --branch main --count 10
```

## Testbox {#testbox}

Testbox lets you run commands in a real Semaphore CI environment before pushing. It creates a warm VM with your project's machine type and syncs your local code.

### sem-ai testbox warmup {#testbox-warmup}

Start a testbox:

```shell
sem-ai testbox warmup --project <project-name>
sem-ai testbox warmup --project <project-name> --machine f1-standard-4 --duration 30m
```

### sem-ai testbox run {#testbox-run}

Sync local changes and run a command:

```shell
sem-ai testbox run --id <testbox-id> "go test ./..."
sem-ai testbox run --id <testbox-id> "make build"
```

### sem-ai testbox ssh {#testbox-ssh}

Open an interactive SSH session:

```shell
sem-ai testbox ssh --id <testbox-id>
```

### sem-ai testbox stop {#testbox-stop}

Stop a running testbox:

```shell
sem-ai testbox stop --id <testbox-id>
```

## Secrets {#secrets}

### sem-ai secret list {#secret-list}

List organization-level secrets, or project-level with `--project`:

```shell
sem-ai secret list
sem-ai secret list --project <project-name>
```

### sem-ai secret show {#secret-show}

Show secret details:

```shell
sem-ai secret show <secret-name>
sem-ai secret show <secret-name> --project <project-name>
```

### sem-ai secret create {#secret-create}

Create a secret with environment variables:

```shell
sem-ai secret create <secret-name> --env KEY=VALUE --env DB_URL=postgres://...
sem-ai secret create <secret-name> --project <project-name> --env API_KEY=abc123
```

### sem-ai secret update {#secret-update}

Update a secret (replaces env vars):

```shell
sem-ai secret update <secret-name> --env KEY=NEW_VALUE
```

### sem-ai secret delete {#secret-delete}

Delete a secret:

```shell
sem-ai secret delete <secret-name>
```

## Deployment targets {#deploys}

### sem-ai deploy targets {#deploy-targets}

List deployment targets:

```shell
sem-ai deploy targets --project <project-name>
```

### sem-ai deploy show {#deploy-show}

Show deployment target details:

```shell
sem-ai deploy show <target-id>
```

### sem-ai deploy history {#deploy-history}

Show deployment history:

```shell
sem-ai deploy history <target-id>
```

### sem-ai deploy create {#deploy-create}

Create a deployment target:

```shell
sem-ai deploy create <name> --project <project-name> --url https://staging.example.com
```

### sem-ai deploy activate / deactivate {#deploy-activate}

Activate or deactivate a deployment target:

```shell
sem-ai deploy activate <target-id>
sem-ai deploy deactivate <target-id>
```

### sem-ai deploy delete {#deploy-delete}

Delete a deployment target:

```shell
sem-ai deploy delete <target-id>
```

## Notifications {#notifications}

### sem-ai notification list {#notification-list}

List notification rules:

```shell
sem-ai notification list
```

### sem-ai notification show {#notification-show}

Show notification details:

```shell
sem-ai notification show <name>
```

### sem-ai notification delete {#notification-delete}

Delete a notification rule:

```shell
sem-ai notification delete <name>
```

## Scheduled tasks {#tasks}

### sem-ai task list {#task-list}

List scheduled tasks:

```shell
sem-ai task list --project <project-name>
```

### sem-ai task show {#task-show}

Show task details:

```shell
sem-ai task show <task-id>
```

### sem-ai task create {#task-create}

Create a scheduled task:

```shell
sem-ai task create <name> --project <project-name> --branch main --file .semaphore/nightly.yml --cron "0 2 * * *"
```

### sem-ai task run {#task-run}

Trigger a task to run now:

```shell
sem-ai task run <task-id>
```

### sem-ai task delete {#task-delete}

Delete a task:

```shell
sem-ai task delete <task-id>
```

## Self-hosted agents {#agents}

### sem-ai agent types {#agent-types}

List self-hosted agent types:

```shell
sem-ai agent types
```

### sem-ai agent show {#agent-show}

Show agent type details:

```shell
sem-ai agent show <type-name>
```

### sem-ai agent list {#agent-list}

List agents for a given type:

```shell
sem-ai agent list --type <type-name>
```

### sem-ai agent delete {#agent-delete}

Delete an agent type:

```shell
sem-ai agent delete <type-name>
```

## Artifacts {#artifacts}

### sem-ai artifact list {#artifact-list}

List artifacts for a job, workflow, or project:

```shell
sem-ai artifact list --scope jobs --id <job-id>
sem-ai artifact list --scope workflows --id <workflow-id>
```

### sem-ai artifact get {#artifact-get}

Download an artifact:

```shell
sem-ai artifact get --scope jobs --id <job-id> --path test-results/junit.json --output ./results.json
```

## Troubleshooting {#troubleshoot}

Server-side diagnostics for workflows, pipelines, and jobs:

```shell
sem-ai troubleshoot workflow <id>
sem-ai troubleshoot pipeline <id>
sem-ai troubleshoot job <id>
```

## YAML validation {#yaml}

Validate a pipeline YAML file against the Semaphore API:

```shell
sem-ai yaml validate --file .semaphore/semaphore.yml
```

## MCP server {#mcp}

sem-ai can run as an MCP (Model Context Protocol) server, exposing all commands as native tools for AI agents.

### Starting the server

```shell
sem-ai mcp
```

### Claude Code configuration

Add to your project's `.mcp.json`:

```json
{
  "mcpServers": {
    "semaphore": {
      "command": "sem-ai",
      "args": ["mcp"]
    }
  }
}
```

All commands become available as MCP tools (e.g., `project_list`, `diagnose`, `status`, `blast-radius`). The server starts once and handles all tool calls through the in-memory command tree.

## Agent skills {#skills}

### sem-ai install-skills {#install-skills}

Install sem-ai skill definitions for AI agents:

```shell
sem-ai install-skills claude
sem-ai install-skills codex
```

Skills provide structured documentation that helps AI agents use sem-ai effectively without reading this reference.

## Differences from sem CLI {#differences}

| Feature | sem | sem-ai |
|---------|-----|-----------|
| Output format | Human text | JSON (default), table, yaml |
| Self-discovery | `--help` only | `discover` + `--examples` on every command |
| Failure diagnosis | Manual (multiple commands) | `diagnose` (one command, full root cause) |
| Test intelligence | None | `test summary`, `test flaky` |
| Pipeline topology | None | `topology`, `critical-path`, `blast-radius` |
| Testbox | `sem debug` (limited) | `testbox warmup/run/ssh/stop` with file sync |
| MCP server | None | `sem-ai mcp` |
| Health reports | None | `health` (pass rates, trends, verdict) |
| Deploy safety | Fire-and-forget | Dry run by default, `--confirm` required |
| Configuration | `~/.sem.yaml` | `~/.sem.yaml` (shared, compatible) |
