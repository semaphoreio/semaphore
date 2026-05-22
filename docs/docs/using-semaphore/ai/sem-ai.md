---
description: Drive Semaphore from an AI agent with the sem-ai CLI and Claude Code / Codex plugin
sidebar_position: 5
---

# sem-ai CLI

This page explains how to install and use `sem-ai`, an agent-first CLI for Semaphore. It pairs with the official Claude Code / Codex plugin that ships Semaphore skills and an embedded MCP server.

## Overview

`sem-ai` is a single binary that wraps the Semaphore APIs in a shape AI agents work well with: structured JSON output by default, self-describing commands, and compound operations that chain workflow → pipeline → failed jobs → logs → parsed test results into one call.

When installed locally, `sem-ai` runs its own MCP server (`sem-ai mcp`). You do **not** need the organization-level [hosted MCP Server](./mcp-server) feature enabled to use it — `sem-ai` talks to the public Semaphore API directly with your personal API token. Use the hosted MCP Server when you want a managed, OAuth-friendly remote endpoint; use `sem-ai` when you want a local CLI plus agent tooling that any team member can install today.

Source and full command reference: [github.com/semaphoreio/sem-ai](https://github.com/semaphoreio/sem-ai).

## Install

```shell
curl -fsSL https://raw.githubusercontent.com/semaphoreio/sem-ai/main/install.sh | sh
```

The installer fetches the latest release for macOS or Linux (amd64 or arm64) and places the binary on your `PATH`. Re-running the same command upgrades to the newest release (and fast-paths if you are already on it).

To opt out of background update checks:

```shell
export SEM_AI_NO_UPDATE_CHECK=1
```

## Connect to your organization

Get an API token from `https://<your-org>.semaphoreci.com/account` and run:

```shell
sem-ai connect <your-org>.semaphoreci.com YOUR_API_TOKEN
```

`sem-ai` writes credentials to `~/.sem.yaml`, the same file used by the legacy [`sem` CLI](https://github.com/semaphoreci/cli), so existing contexts and tokens are reused.

:::tip Prefer a service account token for CI/automation

For shared CI/CD usage, scheduled jobs, and any setup where the token survives a single developer leaving the project, use a per-project [service account](../service-accounts) token instead of a personal API token:

- **Rotation** — service-account tokens are decoupled from a human user. You can rotate the token (or revoke a compromised one) without touching anyone's login session, and without losing access when the original creator leaves the org.
- **Managed access** — service accounts created with the org-level Member role do not get any project access by default. Add the service account to each project's People page that the agent is allowed to touch, and `sem-ai` calls outside that scope return `404 Not Found`. This makes "what can this token reach" auditable in one place.
- **Fine-grained permissions** — if your plan includes [RBAC](../rbac), assign a project role that matches what the agent actually needs (e.g. read-only for a status / diagnose bot, contributor for a deploy bot). Avoid handing it Admin "just in case".

Service accounts are an opt-in org feature — contact `support@semaphore.io` if it is not yet enabled for your organization.

:::

Verify with:

```shell
sem-ai status --project <project> --branch main
```

## Quick start

A few representative commands — every command also supports `--examples` for inline usage:

```shell
# Diagnose a failing branch — composes workflow → pipeline → failed jobs → logs → tests
sem-ai diagnose --project my-app --branch main

# Project health overview
sem-ai health --project my-app

# Validate a pipeline YAML before pushing
sem-ai yaml validate --file .semaphore/semaphore.yml

# Stream a workflow until it completes
sem-ai watch <workflow-id>
```

`sem-ai discover` returns the full capability map.

## Claude Code / Codex plugin

The plugin bundles Semaphore skills, an embedded MCP server, and a SessionStart hook that surfaces update notices in chat. Skills follow the [Agent Skills](https://agentskills.io) standard so the same bundle works in Claude Code, Codex, and any compliant host.

### Install the plugin

From inside Claude Code or Codex:

```
/plugin marketplace add semaphoreio/sem-ai
/plugin install sem-ai@semaphoreio
```

The marketplace is published with `autoUpdate: true`, so the host refreshes the catalog at session start and pulls new skill versions automatically. To force an immediate refresh:

```
/plugin marketplace update semaphoreio
/reload-plugins
```

There is no `/plugin update <plugin>` command — refresh the marketplace and let auto-update apply, or `uninstall` followed by `install` for a forced re-install.

The plugin requires the `sem-ai` binary to be on `PATH`. If you install the plugin before the binary, the SessionStart hook prints a one-line install hint in chat.

### Slash-command entry points

User-invocable skills can be triggered directly with a namespaced slash command — useful when the activation keyword in a skill's description does not match your prompt verbatim:

| Slash command | What it does |
|---|---|
| `/sem-ai:init` | Initialize Semaphore CI/CD for the current repo. Detects state — GitHub Actions workflows present, greenfield, or `.semaphore/` already there — applies Semaphore-side defaults (`f1-standard-2` + `ubuntu2404` agent, `checkout` in `global_job_config.prologue`, `sem-version` for language pinning, `cache` keyed on `$(checksum <lockfile>)`, `test-results publish` in `epilogue.always.commands`, explicit `dependencies:` on every block, `auto_cancel` on non-`main`/`master`), validates with `sem-ai yaml validate`, wires required secrets, and opens a PR. |
| `/sem-ai:gha-to-semaphore` | Translate-only — same procedure as the `init` translate path, scoped to converting `.github/workflows/*` into a Semaphore pipeline. See also the [GitHub Actions migration page](../../getting-started/migration/github-actions). |

Other skills load automatically when their description keywords match the user's prompt. The slash commands above are explicit triggers for the most common entry points.

### What ships in the plugin

Skills the plugin loads into your agent:

| Skill | Purpose |
|---|---|
| `semaphore-ci` | Manage Semaphore CI/CD via `sem-ai` — status, failures, test results, deployments, secrets, notifications |
| `semaphore-blocks` | Pipeline structure — blocks, tasks, jobs, dependencies, parallelism cost-benefit, `auto_cancel` |
| `semaphore-promotions` | Promotion concepts, parameterized deploys, deployment-target gating |
| `semaphore-test-results` | Publishing JUnit reports — epilogue rule, per-framework JUnit config |
| `semaphore-toolbox` | Preinstalled toolbox CLIs — `cache`, `artifact`, `retry`, `sem-version`, `sem-service`, `checkout` |
| `gha-to-semaphore` | Translate GitHub Actions workflows to Semaphore pipelines |
| `init` | Orchestrator for `/sem-ai:init` |
| `testbox` | Run CI commands against local changes in a real Semaphore environment |
| `probe-agent-environment` | Discover what is preinstalled on a Semaphore agent via a short-lived testbox |
| `test-intelligence` | Pull and analyze test results, detect flaky tests |
| `debug-pipeline` | Step-by-step CI failure diagnosis |
| `deploy` | Deploy via Semaphore promotions |
| `manage-infra` | Manage secrets, notifications, agent types, scheduled tasks, artifacts |
| `project-health` | Pass rates, recent failures, deployment trends |
| `sem-ai-bootstrap` | Diagnose sem-ai plugin issues (binary missing, MCP not registering, …) |

### Embedded MCP server

The plugin registers `sem-ai mcp` as an MCP server inside the host, so every `sem-ai` command becomes a native tool the agent can call without a shell round-trip.

To register `sem-ai mcp` manually in any MCP-aware client, add to `.mcp.json` in your project:

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

This is local: the MCP server runs on the same machine as the agent, using your `sem-ai connect` credentials. Long-running commands (`watch`, `promote-and-wait`) are excluded from the MCP surface to prevent blocking the agent.

## Bootstrap a project from the CLI

`sem-ai project create` registers a new Semaphore project and, when run from a git working directory, writes a starter `.semaphore/semaphore.yml`:

```shell
sem-ai project create \
  --name my-app \
  --github-integration github_token
```

Flags:

- `--name <name>` — project name. Defaults to the basename of the current working directory.
- `--repo-url <url>` — repository URL. Auto-detected from the `origin` remote when omitted.
- `--github-integration <type>` — one of `github_token` (default), `github_app`, `github_oauth_token`, `bitbucket`, `gitlab`.
- `--remote <name>` — which git remote to read the URL from. Defaults to `origin`.
- `--skip-yaml` — skip writing `.semaphore/semaphore.yml`.

For an AI-driven flow that wires secrets and translates GitHub Actions if present, use `/sem-ai:init` from the plugin instead.

## Updates

A `SessionStart` hook checks GitHub for new releases at most once every 6 hours and surfaces an upgrade banner in chat when one is available. To force a check from a shell:

```shell
sem-ai version --check
```

Upgrade by re-running the install script.

## See also

- [MCP Server](./mcp-server) — Semaphore-hosted remote MCP endpoint (organization feature)
- [GitHub Actions migration](../../getting-started/migration/github-actions) — uses `/sem-ai:gha-to-semaphore` as the recommended path
- [Self-Healing CI](./self-healing-ci) — automated build-fix workflows
- [Toolbox reference](../../reference/toolbox) — the CLIs the `semaphore-toolbox` skill teaches the agent about
