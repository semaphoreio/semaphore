---
description: Drive Semaphore from an AI agent with the sem-ai CLI and Claude Code / Codex plugin
sidebar_position: 5
---

# sem-ai CLI

`sem-ai` is an agent-first command line tool for Semaphore, paired with an optional Claude Code / Codex plugin. This page explains the pieces, how to install them, and when to reach for each.

## Overview

`sem-ai` is **one binary** with **two artifacts and three ways to use it**:

1. **CLI binary** — direct terminal and API access. Structured JSON output by default, self-describing commands, and compound operations that chain workflow → pipeline → failed jobs → logs → parsed test results into a single call (`diagnose`, `status`, `health`, `yaml validate`, `project create`, …).
2. **Embedded MCP server** — the same binary, run as `sem-ai mcp`, exposes every command as a native tool to any MCP-aware agent. This is a mode of the binary, not a separate download.
3. **Claude Code / Codex plugin** — an optional bundle that installs Semaphore [Agent Skills](https://agentskills.io), namespaced slash commands (`/sem-ai:init`, `/sem-ai:gha-to-semaphore`), and a `SessionStart` update hook — and registers the embedded MCP server with the host automatically.

The CLI works on its own for terminal and API workflows; **you do not need the plugin**. The plugin is what gives an AI agent Semaphore skills, slash-command entry points, and automatic MCP registration.

### What you can do with it

- **Bootstrap a project on Semaphore from a single prompt** — `/sem-ai:init` translates an existing `.github/workflows/*` or drafts a greenfield `.semaphore/semaphore.yml`, applying Semaphore-side defaults (machine type, `checkout` in prologue, `sem-version` for languages, cache keyed on lockfile, `test-results publish` in epilogue, …).
- **Debug a failing pipeline without leaving the terminal** — `sem-ai diagnose` composes workflow → pipeline → failed jobs → logs → parsed test results into one call; `sem-ai test summary` parses published JUnit reports in under a second instead of patching reporters to print to stdout.
- **Operate full CI/CD from an agent** — manage projects, secrets, notifications, deploy targets, scheduled tasks, and promotions; validate YAML before pushing; run commands against a real Semaphore agent via `sem-ai testbox` to iterate on CI fixes before committing.

## When to use sem-ai vs the hosted MCP Server

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

## Install and set up

The flow is: install the CLI binary → connect to your organization → (optionally) install the plugin.

### 1. Install the CLI binary

```shell
curl -fsSL https://raw.githubusercontent.com/semaphoreio/sem-ai/main/install.sh | sh
```

The installer fetches the latest release for macOS or Linux (amd64 or arm64). It installs to `~/.local/bin` when that directory is already on your `PATH`; otherwise it installs to `~/.semaphore-ai/bin` and prints a note asking you to add that directory to your `PATH`.

### 2. Connect to your organization

Get an API token from `https://me.semaphoreci.com/account` and run:

```shell
sem-ai connect <your-org>.semaphoreci.com YOUR_API_TOKEN
```

`sem-ai` writes credentials to `~/.sem.yaml`, the same file used by the legacy [`sem` CLI](https://github.com/semaphoreci/cli), so existing contexts and tokens are reused.

For shared or headless setups — a chatops bot, an internal dashboard, or a non-Semaphore CI job that calls the Semaphore API — use a [service account](../service-accounts) token instead, so access and rotation are not tied to any single user.

Verify with:

```shell
sem-ai status --project <project> --branch main
```

At this point the CLI is fully usable on its own. Install the plugin only if you want the agent ergonomics described below.

### 3. (Optional) Install the Claude Code / Codex plugin

The plugin requires the `sem-ai` binary to be on your `PATH` — install it first (step 1). If you install the plugin before the binary, the `SessionStart` hook prints a one-line install hint in chat.

From inside Claude Code or Codex:

```text
/plugin marketplace add semaphoreio/sem-ai
/plugin install sem-ai@semaphoreio
```

### Staying up to date

There are two independent things to keep current:

- **The CLI binary.** Re-run the install script to upgrade — it fast-paths if you are already on the latest release. A background check notifies you when a newer release exists; force a check from a shell with `sem-ai version --check`, or opt out with `export SEM_AI_NO_UPDATE_CHECK=1`. Inside the plugin, a `SessionStart` hook surfaces the same upgrade banner in chat (at most once every 6 hours).
- **The plugin skills.** These come from the marketplace catalog, not the binary. A third-party marketplace like this one does not auto-update by default — refresh it on demand with `/plugin marketplace update semaphoreio` followed by `/reload-plugins`. To keep it current automatically, enable auto-update for the marketplace (`/plugin` → **Marketplaces** → **semaphoreio** → **Enable auto-update**). You can also update an installed plugin directly with `/plugin update`, or `uninstall` then `install` for a forced re-install.

## Common CLI commands

A few representative commands — every command also supports `--examples` for inline usage:

```shell
# Diagnose a failing branch — composes workflow → pipeline → failed jobs → logs → tests
sem-ai diagnose --project my-app --branch main

# Project health overview
sem-ai health --project my-app

# Validate a pipeline YAML before pushing
sem-ai yaml validate --file .semaphore/semaphore.yml

# Poll a workflow until it completes (default 30s interval)
sem-ai watch <workflow-id>
```

`sem-ai discover` returns the full capability map. For the complete command list, see the [sem-ai Command Line reference](../../reference/sem-ai-cli).

## Plugin capabilities

The plugin bundles four things and works in Claude Code, Codex, and any [Agent Skills](https://agentskills.io)-compliant host:

- **Skills** — in-context Semaphore knowledge the agent loads on demand.
- **Slash commands** — explicit entry points for the most common workflows.
- **Embedded MCP server** — automatic registration of `sem-ai mcp` with the host.
- **`SessionStart` hook** — surfaces CLI upgrade banners (see [Staying up to date](#staying-up-to-date)).

### Skills

Each skill teaches the agent one Semaphore concept (blocks, promotions, toolbox CLIs, test-results, GHA translation, testbox, deploys, manage-infra, …) and loads automatically when its description keywords match the user's prompt.

For the canonical inventory and per-skill documentation, browse [`assets/plugin/skills/`](https://github.com/semaphoreio/sem-ai/tree/main/assets/plugin/skills) in the sem-ai repository — that directory is the source of truth and updates as new skills land.

### Slash commands

User-invocable skills can be triggered directly with a namespaced slash command — useful when the activation keyword in a skill's description does not match your prompt verbatim:

| Slash command | What it does |
|---|---|
| `/sem-ai:init` | Initialize Semaphore CI/CD for the current repo. Detects state — GitHub Actions workflows present, greenfield, or `.semaphore/` already there — applies Semaphore-side defaults (`f1-standard-2` + `ubuntu2404` agent, `checkout` in `global_job_config.prologue`, `sem-version` for language pinning, `cache` keyed on `$(checksum <lockfile>)`, `test-results publish` in `epilogue.always.commands`, explicit `dependencies:` on every block, `auto_cancel` on non-`main`/`master`), validates with `sem-ai yaml validate`, wires required secrets, and opens a PR. |
| `/sem-ai:gha-to-semaphore` | Translate-only — same procedure as the `init` translate path, scoped to converting `.github/workflows/*` into a Semaphore pipeline. See also the [GitHub Actions migration page](../../getting-started/migration/github-actions). |

Other skills load automatically when their description keywords match the user's prompt. The slash commands above are explicit triggers for the most common entry points.

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

## Create a project from the CLI

If you prefer the CLI over the agent flow, `sem-ai project create` registers a new Semaphore project and, when run from a git working directory, writes a starter `.semaphore/semaphore.yml`:

```shell
sem-ai project create \
  --name my-app \
  --github-integration github_token
```

Flags:

- `--name <name>` — project name. Defaults to the repository name derived from the repo URL (e.g. `org/repo.git` → `repo`).
- `--repo-url <url>` — repository URL. Auto-detected from the `origin` remote when omitted.
- `--github-integration <type>` — `github_token` (default) or `github_app`.
- `--remote <name>` — which git remote to read the URL from. Defaults to `origin`.
- `--skip-yaml` — skip writing `.semaphore/semaphore.yml`.

For an AI-driven flow that wires secrets and translates GitHub Actions if present, use `/sem-ai:init` from the plugin instead.

## See also

- [MCP Server](./mcp-server) — Semaphore-hosted remote MCP endpoint (organization feature)
- [GitHub Actions migration](../../getting-started/migration/github-actions) — uses `/sem-ai:gha-to-semaphore` as the recommended path
- [Self-Healing CI](./self-healing-ci) — automated build-fix workflows
- [Toolbox reference](../../reference/toolbox) — the CLIs the `semaphore-toolbox` skill teaches the agent about
- [sem-ai Command Line reference](../../reference/sem-ai-cli) — full CLI command reference
- Source: [github.com/semaphoreio/sem-ai](https://github.com/semaphoreio/sem-ai)
