---
description: Automatically fix tests in CI using an AI Agent and the MCP Server
sidebar_position: 2
---

# Autofix Tests in CI using Agents

This page explains how to implement a automatic test fixes on your CI with the help of an AI agent and the [Semaphore MCP server](./mcp-server).

## Overview

AI Agents such as OpenAI Codex or Claude Code can diagnose and fix test errors in your CI. When coupled with Semaphore's MCP server, these agents can implement and push fixes automatically when a pipeline fails.

The autofix process works in this way:

1. You have a regular CI pipeline that builds and tests your application
2. You add a [promotion] that triggers the autofix pipeline when the CI fails
3. The autofix pipeline spins up an AI agent. The agent pulls the job logs using Semaphore's MCP and implements a fix
4. The last command in the autofix pipeline pushes the fixed code into an separate branch
5. The push triggers a new CI build. If the pipeline passes this time, you merge the fixed branch into the trunk

TODO: diagram

## Preventing build loops

Whenever we push into the repository from inside the CI environment, we risk entering into a loop. In this solution, we present two mechanisms:

- Always run the autofix pipeline manually, i.e. without [autopromotion]
- Enable autopromotions, but use [conditions] to avoid triggering on branches created by previous autofix runs

## Prerequisites

- Semaphore [MCP Server](./mcp-server) enabled and configured in your organization
- A [GitHub Personal Access Token](https://github.com/settings/tokens) with write permissions on the repository
- An API token for your AI Agent of choice

## Preparation




