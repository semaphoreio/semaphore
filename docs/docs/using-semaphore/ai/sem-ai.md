---
description: Drive Semaphore from an AI agent with the sem-ai CLI and Claude Code / Codex plugin
sidebar_position: 5
---

# sem-ai CLI

This page explains how to install and use `sem-ai`, an agent-first CLI for Semaphore. It pairs with the official Claude Code / Codex plugin that ships Semaphore skills and an embedded MCP server.

## Overview

`sem-ai` is a single binary that wraps the Semaphore APIs in a shape AI agents work well with: structured JSON output by default, self-describing commands, and compound operations that chain workflow → pipeline → failed jobs → logs → parsed test results into one call.

### Why it exists

Agents driving Semaphore from a developer's machine need three things that a remote MCP server cannot provide on its own: a full write-surface to manage projects, secrets, deploy targets, and YAML; in-context **skills** that teach the agent Semaphore's conventions (block dependencies, the `epilogue` rule for test reports, toolbox CLIs, sharding cost-benefit, …) so it does not invent wrong defaults; and a deterministic entry point for repetitive set-up tasks like translating GitHub Actions or bootstrapping a fresh project.

`sem-ai` packages all three: the CLI exposes the full Semaphore API surface, the Claude Code / Codex plugin ships [Agent Skills](https://agentskills.io) covering each Semaphore concept, and the `/sem-ai:init` slash command orchestrates project bootstrap end to end (detect repo state → translate or draft → validate → wire secrets → open a PR).

### What it helps with

- **Bootstrap a project on Semaphore from a single prompt** — `/sem-ai:init` covers translating an existing `.github/workflows/*` or drafting a greenfield `.semaphore/semaphore.yml`, applying Semaphore-side defaults (machine type, `checkout` in prologue, `sem-version` for languages, cache keyed on lockfile, `test-results publish` in epilogue, …).
- **Debug a failing pipeline without leaving the terminal** — `sem-ai diagnose` composes workflow → pipeline → failed jobs → logs → parsed JUnit into one call; `sem-ai test summary` parses published reports in under a second instead of patching reporters to print to stdout.
- **Operate full CI/CD from an agent** — manage projects, secrets, notifications, deploy targets, scheduled tasks, and promotions; validate YAML before pushing; run commands against a real Semaphore agent via `sem-ai testbox` to iterate on CI fixes before committing.

### sem-ai vs the hosted MCP Server

Both let AI agents talk to Semaphore. They are complementary, and you can use them at the same time. Use this table to pick.

| | [Hosted MCP Server](./mcp-server) | sem-ai |
|---|---|---|
| **Where it runs** | Semaphore-managed endpoint at `mcp.semaphoreci.com` | Local binary on the developer's machine |
| **Setup** | Opt-in per org — contact `support@semaphore.io` | Install the binary; no feature flag required |
| **Auth** | OAuth 2.1 (browser), personal API token, or [service account](../service-accounts) API token | Personal API token (or [service account](../service-accounts) token for shared/headless setups) |
| **Scope** | A focused MCP tool set: orgs, projects, workflows, pipelines, jobs, logs, test results, doc lookup, workflow run/rerun | The full Semaphore API surface — projects, secrets, deploy targets, notifications, scheduled tasks, agents, artifacts, YAML validation, testbox, plus the same read/diagnose tools |
| **Skills** | Tool descriptions only | [Agent Skills](https://agentskills.io) covering blocks, promotions, toolbox CLIs, test-results, GHA translation, debugging, deploys, manage-infra, testbox, etc |
| **Slash commands** | `/semaphore:mcp_setup` (auto-discover project and organization IDs — see [usage examples](./mcp-usage-examples)) | `/sem-ai:init` (bootstrap a project), `/sem-ai:gha-to-semaphore` (translate workflows) |
| **Best for** | Any MCP-aware agent that should reach into Semaphore from the web — Claude desktop, Cursor, VS Code, internal copilots — without each user installing a CLI | Driving Semaphore from a terminal-attached agent (Claude Code, Codex), bootstrapping CI on new projects, fixing failing pipelines on a developer laptop, automating Semaphore from non-Semaphore CI |

In short: the hosted MCP Server is the remote, managed access path; `sem-ai` is the local, fully-featured agent toolkit that ships with opinionated Semaphore knowledge.

Full command reference: [sem-ai Command Line](../../reference/sem-ai-cli). Source: [github.com/semaphoreio/sem-ai](https://github.com/semaphoreio/sem-ai).

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

For shared or headless setups — a chatops bot, an internal dashboard, or a non-Semaphore CI job that calls the Semaphore API — use a [service account](../service-accounts) token instead, so access and rotation are not tied to any single user.

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

```text
/plugin marketplace add semaphoreio/sem-ai
/plugin install sem-ai@semaphoreio
```

The marketplace is published with `autoUpdate: true`, so the host refreshes the catalog at session start and pulls new skill versions automatically. To force an immediate refresh:

```text
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

Each skill teaches the agent one Semaphore concept (blocks, promotions, toolbox CLIs, test-results, GHA translation, testbox, deploys, manage-infra, …) and loads automatically when its description keywords match the user's prompt.

For the canonical inventory and per-skill documentation, browse [`assets/plugin/skills/`](https://github.com/semaphoreio/sem-ai/tree/main/assets/plugin/skills) in the sem-ai repository — that directory is the source of truth and updates as new skills land.

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
