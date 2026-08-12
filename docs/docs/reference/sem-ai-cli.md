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

```shell
curl -fsSL https://raw.githubusercontent.com/semaphoreio/sem-ai/main/install.sh | sh
```

Installs the latest release for macOS / Linux on amd64 / arm64. The binary lands at `$HOME/.local/bin/sem-ai` (or `$HOME/.semaphore-ai/bin/sem-ai` if that's not on your `$PATH`). Re-run the same command to upgrade.

### From source

Requires Go 1.25+.

```shell
git clone https://github.com/semaphoreio/sem-ai.git
cd sem-ai
make install
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

### sem-ai project create {#project-create}

Create a project from a git repository. With no flags it uses the `origin` remote of the current directory and derives the name from the repo URL, then bootstraps an initial `.semaphore/semaphore.yml` (unless `--skip-yaml`). If a project with the same name already exists it returns the existing one, unless `--fail-on-exists` is set.

```shell
sem-ai project create
sem-ai project create --repo-url git@github.com:org/repo.git
sem-ai project create --name my-project --github-integration github_app
```

| Flag | Default | Description |
|------|---------|-------------|
| `--repo-url` | `origin` of cwd | git repository URL |
| `--name` | derived from repo URL | project name |
| `--github-integration` | `github_token` | GitHub integration: `github_token` or `github_app` |
| `--remote` | `origin` | git remote to detect when `--repo-url` is not set |
| `--skip-yaml` | `false` | don't generate `.semaphore/semaphore.yml` in cwd |
| `--fail-on-exists` | `false` | exit non-zero if a project with the same name already exists |

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

## Managing organization members and roles {#org-management}

### sem-ai org member list {#org-member-list}

List organization members, optionally filtered by member type:

```shell
sem-ai org member list
sem-ai org member list --type service_account
sem-ai org member list --type group
```

| Flag | Default | Description |
|------|---------|-------------|
| `--type` | `user` | filter by member type: `user`, `service_account`, or `group` |

### sem-ai org member add {#org-member-add}

Invite a person to the organization by their SCM handle:

```shell
sem-ai org member add --provider github --handle octocat
sem-ai org member add --provider github --handle octocat --role <role-id> --name "Octo Cat" --email octo@example.com
sem-ai org member add --provider bitbucket --handle jdoe --uid 557058:1a2b3c
```

| Flag | Default | Description |
|------|---------|-------------|
| `--handle` | — | SCM login/handle of the person to invite (required) |
| `--provider` | — | SCM provider: `github`, `bitbucket`, or `gitlab` (required) |
| `--uid` | — | SCM user ID (required for `bitbucket`) |
| `--role` | — | org role ID to assign |
| `--name` | — | display name |
| `--email` | — | email address |

### sem-ai org member set-role {#org-member-set-role}

Assign or change a member's org-level role. This is an upsert — the same command creates the initial role assignment and changes it later.

```shell
sem-ai org member set-role <user-id> <role-id>
sem-ai org member set-role <service-account-id> <role-id>
```

### sem-ai org member remove {#org-member-remove}

Remove a member or service account from the organization:

```shell
sem-ai org member remove <user-id>
```

### sem-ai org role list {#org-role-list}

List organization roles, including built-in and custom roles:

```shell
sem-ai org role list
```

### sem-ai org role show {#org-role-show}

Show role details, including its permission set:

```shell
sem-ai org role show <role-id>
```

### sem-ai org role create {#org-role-create}

Create a custom role:

```shell
sem-ai org role create deployer --permissions "project.view,project.job.rerun"
sem-ai org role create viewer --scope project --permissions "project.view"
```

| Flag | Default | Description |
|------|---------|-------------|
| `--description` | — | role description |
| `--scope` | `org` | role scope: `org` or `project` |
| `--permissions` | — | comma-separated permission names, e.g. `organization.people.view,organization.people.manage` |

### sem-ai org role update {#org-role-update}

Update a custom role:

```shell
sem-ai org role update <role-id> --permissions "project.view,project.job.rerun"
```

| Flag | Default | Description |
|------|---------|-------------|
| `--name` | — | new role name |
| `--description` | — | new role description |
| `--permissions` | — | comma-separated permission names (replaces the existing set) |

### sem-ai org role delete {#org-role-delete}

Delete a custom role:

```shell
sem-ai org role delete <role-id>
```

### sem-ai permission list {#permission-list}

List available permissions, optionally filtered by scope:

```shell
sem-ai permission list
sem-ai permission list --scope project
```

| Flag | Default | Description |
|------|---------|-------------|
| `--scope` | — | filter by scope: `org` or `project` |

## Managing groups {#groups}

### sem-ai group list {#group-list}

List groups in the organization:

```shell
sem-ai group list
```

### sem-ai group create {#group-create}

Create a group:

```shell
sem-ai group create backend-team
sem-ai group create backend-team --description "Backend engineers" --members "id1,id2"
```

| Flag | Default | Description |
|------|---------|-------------|
| `--description` | — | group description |
| `--members` | — | comma-separated member IDs to add on creation |

### sem-ai group update {#group-update}

Update a group's name, description, or membership:

```shell
sem-ai group update <group-id> --add "id1,id2" --remove "id3"
sem-ai group update <group-id> --name "new-name"
```

| Flag | Default | Description |
|------|---------|-------------|
| `--name` | — | new group name |
| `--description` | — | new group description |
| `--add` | — | comma-separated member IDs to add |
| `--remove` | — | comma-separated member IDs to remove |

### sem-ai group delete {#group-delete}

Delete a group:

```shell
sem-ai group delete <group-id>
```

## Managing service accounts {#service-accounts}

### sem-ai service-account list {#service-account-list}

List service accounts in the organization:

```shell
sem-ai service-account list
```

### sem-ai service-account create {#service-account-create}

Create a service account. The API token is only ever returned in this create response — save it now, since `service-account show` never returns it again (use `regenerate-token` if it's lost).

```shell
sem-ai service-account create ci-bot
sem-ai service-account create ci-bot --description "Bot for CI pipelines"
```

| Flag | Default | Description |
|------|---------|-------------|
| `--description` | — | service account description |

### sem-ai service-account show {#service-account-show}

Show service account details:

```shell
sem-ai service-account show <service-account-id>
```

### sem-ai service-account update {#service-account-update}

Update a service account's name or description. The API replaces the whole record on update, so if `--name` is omitted, sem-ai first fetches the current name and resends it unchanged to avoid clearing it.

```shell
sem-ai service-account update <service-account-id> --name "new-name"
sem-ai service-account update <service-account-id> --description "new description"
```

| Flag | Default | Description |
|------|---------|-------------|
| `--name` | — | new service account name |
| `--description` | — | new service account description |

### sem-ai service-account delete {#service-account-delete}

Delete a service account:

```shell
sem-ai service-account delete <service-account-id>
```

### sem-ai service-account deactivate {#service-account-deactivate}

Deactivate a service account, disabling its token without deleting the account:

```shell
sem-ai service-account deactivate <service-account-id>
```

### sem-ai service-account reactivate {#service-account-reactivate}

Reactivate a previously deactivated service account:

```shell
sem-ai service-account reactivate <service-account-id>
```

### sem-ai service-account regenerate-token {#service-account-regenerate-token}

Regenerate a service account's API token. The old token is invalidated and the new one is printed once in the response — save it immediately.

```shell
sem-ai service-account regenerate-token <service-account-id>
```

## Managing project members {#project-members}

### sem-ai project member list {#project-member-list}

List project members:

```shell
sem-ai project member list my-project
```

### sem-ai project member set-role {#project-member-set-role}

Set a project-level role for a member:

```shell
sem-ai project member set-role my-project <user-id> <role-id>
```

### sem-ai project member remove {#project-member-remove}

Remove a member's project-level role:

```shell
sem-ai project member remove my-project <user-id>
```

## Compound commands {#compound}

These commands compose multiple API calls into a single operation.

### sem-ai status {#status}

Quick CI status for the current branch, a pull request, or a project. When run inside a git checkout, project and branch are auto-detected from the remote and HEAD, and status prefers the workflow for the exact HEAD commit, falling back to the latest run on the branch.

```shell
sem-ai status                                    # current repo, branch, commit
sem-ai status --branch main
sem-ai status --pr 422                           # match a pull request's workflow (overrides --branch)
sem-ai status --project <project-name> --branch feature-x
```

If the git remote maps to several Semaphore projects that each ran the commit, status returns all of them rather than guessing — pass `--project` to disambiguate.

With `--exit-code`, status sets a poll-friendly process exit code instead of requiring output parsing — useful for shell wait-loops:

| Exit | Meaning |
|------|---------|
| `0` | passed |
| `1` | failed |
| `2` | ambiguous (multiple matching projects) |
| `3` | no workflow found / project not detected |
| `8` | pending / running |

```shell
until sem-ai status --exit-code; do sleep 20; done   # wait until green
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
- `stop_reason` when a job was stopped by a signal rather than a test failure — exit `130` (SIGINT), `137` (SIGKILL / OOM), or `143` (SIGTERM). This is most useful for exit `130`, where the job shows up as `STOPPED` and failure notifications are suppressed, so the cause is otherwise easy to miss.

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
sem-ai version --check          # also check GitHub for a newer release
```

When sem-ai is installed via the Claude Code / Codex plugin, a `SessionStart` hook surfaces a one-line upgrade notice at most once every few hours. Opt out with `export SEM_AI_NO_UPDATE_CHECK=1`.

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

## Pipeline insights {#insights}

Server-side pipeline insights, keyed by a specific pipeline YAML file. This is distinct from `analytics`, which sem-ai computes client-side from recent workflows: `insights` reads pre-aggregated metrics from Semaphore for one pipeline file.

All `insights` subcommands share these flags:

| Flag | Default | Description |
|------|---------|-------------|
| `--project` | auto-detected | project name or ID |
| `--pipeline-file` | — | pipeline YAML path, e.g. `.semaphore/semaphore.yml` (required) |
| `--branch` | all branches | branch name |
| `--from` | — | start date `YYYY-MM-DD` |
| `--to` | — | end date `YYYY-MM-DD` |
| `--aggregate` | `daily` | aggregation: `daily` or `range` |

### sem-ai insights performance {#insights-performance}

Pipeline duration metrics over time.

```shell
sem-ai insights performance --project my-app --pipeline-file .semaphore/semaphore.yml --branch main
```

### sem-ai insights reliability {#insights-reliability}

Pipeline pass/fail rate over time.

```shell
sem-ai insights reliability --project my-app --pipeline-file .semaphore/semaphore.yml --branch main
```

### sem-ai insights frequency {#insights-frequency}

Pipeline run frequency over time.

```shell
sem-ai insights frequency --project my-app --pipeline-file .semaphore/semaphore.yml --branch main
```

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

## Flaky tests {#flaky}

History-backed flaky-test signals for a project, sourced from Semaphore's flaky-test history (per-context pass rate, p95, disruption counts). This is distinct from [`test flaky`](#test-flaky), which is a quick single-pipeline snapshot computed from JUnit artifacts; the `flaky` command group reads the accumulated history instead.

All `flaky` subcommands require `--project` (name or ID).

### sem-ai flaky list {#flaky-list}

List a project's flaky tests. The heavy per-test `disruption_history` histogram is omitted by default for compact output; pass `--full` to include it.

```shell
sem-ai flaky list --project my-app
sem-ai flaky list --project my-app --sort-field pass_rate --sort-dir asc
sem-ai flaky list --project my-app --full
```

| Flag | Default | Description |
|------|---------|-------------|
| `--page` | `1` | page number |
| `--page-size` | `20` | results per page |
| `--sort-field` | — | sort field, e.g. `total_disruptions_count`, `pass_rate` |
| `--sort-dir` | — | sort direction (`asc` or `desc`) |
| `--full` | `false` | include full `disruption_history` per test |

### sem-ai flaky show {#flaky-show}

Show details for a single flaky test (per-context pass rate, p95, disruptions). `test_id` is positional.

```shell
sem-ai flaky show <test_id> --project my-app
```

### sem-ai flaky disruptions {#flaky-disruptions}

List the individual disruption occurrences for a flaky test.

```shell
sem-ai flaky disruptions <test_id> --project my-app --page-size 50
```

| Flag | Default | Description |
|------|---------|-------------|
| `--page` | `1` | page number |
| `--page-size` | `10` | results per page |

### sem-ai flaky failure {#flaky-failure}

Show the real failure behind a flaky test: resolves its latest disruption's job, fetches that job's log, and extracts the failing assertion / message. Use `--run-id` to point at a specific job directly instead of resolving the latest disruption.

```shell
sem-ai flaky failure <test_id> --project my-app
sem-ai flaky failure <test_id> --project my-app --run-id <job-id>
```

### sem-ai flaky trends {#flaky-trends}

Project-level flaky / disruption count time series.

```shell
sem-ai flaky trends --project my-app
sem-ai flaky trends --project my-app --metric disruptions
```

| Flag | Default | Description |
|------|---------|-------------|
| `--metric` | `flaky` | series: `flaky` or `disruptions` |

## Testbox {#testbox}

Testbox lets you run commands in a real Semaphore CI environment before pushing. It creates a warm VM with your project's machine type and syncs your local code.

### sem-ai testbox warmup {#testbox-warmup}

Start a testbox:

```shell
sem-ai testbox warmup --project <project-name>
sem-ai testbox warmup --project <project-name> --machine f1-standard-4 --duration 30m
sem-ai testbox warmup --project <project-name> --os-image ubuntu2404
```

Defaults: `--machine f1-standard-2`, `--os-image ubuntu2204`, `--duration 30m`.

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
    "sem-ai": {
      "command": "sem-ai",
      "args": ["mcp"]
    }
  }
}
```

Most commands become available as MCP tools (e.g., `project_list`, `diagnose`, `status`, `blast-radius`). The long-running commands `watch` and `promote-and-wait` are excluded, since they would block the single in-memory command tree; use `status --exit-code` in a poll loop instead. The server starts once and handles all tool calls in-process — no new process per call.

## Agent skills {#skills}

sem-ai ships its skills as a plugin for Claude Code and Codex. The plugin bundles the skills, the MCP server, and a `SessionStart` hook (release-update check + Semaphore-repo awareness).

### Claude Code / Codex plugin {#plugin}

**Claude Code:**

```text
/plugin marketplace add semaphoreio/sem-ai
/plugin install sem-ai@semaphoreio
```

**Codex CLI:**

```shell
codex plugin marketplace add semaphoreio/sem-ai
codex plugin add sem-ai@semaphoreio
```

The bundle includes these skills: `debug-pipeline`, `deploy`, `fix-flaky`, `gha-to-semaphore`, `init`, `manage-infra`, `probe-agent-environment`, `project-health`, `sem-ai-bootstrap`, `semaphore-blocks`, `semaphore-ci`, `semaphore-promotions`, `semaphore-test-results`, `semaphore-toolbox`, `test-intelligence`, `testbox`, and `watch-after-push`. They give agents context on when and how to use each sem-ai command without reading this reference.

### npx skills {#npx-skills}

You can also install the skill bundle with the cross-agent [`skills`](https://github.com/vercel-labs/skills) tool, which supports Claude Code, Cursor, Codex, OpenCode, and many other agents. It discovers sem-ai's skills from the plugin manifest, so no clone is required:

```shell
npx skills add semaphoreio/sem-ai --list             # list available skills
npx skills add semaphoreio/sem-ai --all              # install all skills
npx skills add semaphoreio/sem-ai --skill semaphore-ci --skill watch-after-push
npx skills add semaphoreio/sem-ai --all -g           # user level (all repos)
npx skills add semaphoreio/sem-ai --all --agent cursor opencode
```

This installs the skill instructions only — not the MCP server. The `sem-ai` binary must be [installed](#install) and [connected](#connect) first, since every skill calls it.

## Differences from sem CLI {#differences}

| Feature | sem | sem-ai |
|---------|-----|-----------|
| Output format | Human text | JSON (default), table, yaml |
| Self-discovery | `--help` only | `discover` + `--examples` on every command |
| Failure diagnosis | Manual (multiple commands) | `diagnose` (one command, full root cause) |
| Test intelligence | None | `test summary`, `test flaky`, `flaky` history, `insights` |
| Pipeline topology | None | `topology`, `critical-path`, `blast-radius` |
| Testbox | `sem debug` (limited) | `testbox warmup/run/ssh/stop` with file sync |
| MCP server | None | `sem-ai mcp` |
| Health reports | None | `health` (pass rates, trends, verdict) |
| Deploy safety | Fire-and-forget | Dry run by default, `--confirm` required |
| Configuration | `~/.sem.yaml` | `~/.sem.yaml` (shared, compatible) |
