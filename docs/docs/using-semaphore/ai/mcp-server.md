---
description: Connect your AI Agent with Semaphore using an MCP Server
sidebar_position: 1
---

# MCP Server

This page explains how Semaphore's MCP Server works, how to configure your clients/agents, and what capabilities are available.

:::info Request access to this feature

If you want to try the MCP Server, contact `support@semaphore.io` so we can enable this feature in your organization at no cost.

:::

## Overview

[MCP servers](https://modelcontextprotocol.info/) (Model Context Protocol servers) connect AI models to external data and tools through a standardized interface. They provide structured, real-time context-like data from APIs so models can retrieve accurate information and perform actions securely and consistently.

You can connect your favorite AI agent with Semaphore using the official MCP Server. This allows the AI agent or IDE to access the activity in your organization using a conversational interface. 

With MCP, you can now ask your AI agent why your build failed and to provide a fix.

## MCP Server Capabilities {#tools}

Semaphore's MCP Server provides access to your Semaphore organization via the following tools:

- `echo`: Returns the provided `message` verbatim (handy for smoke tests) 
- `organizations_list`: Lists organizations that the user can access
- `projects_list`: List projects that belong to a specific organization
- `projects_search`: Search projects inside an organization by project name, repository URL, or description
- `workflows_search`: Search recent workflows for a project (most recent first) 
- `pipelines_list`: List pipelines associated with a workflow (most recent first)
- `pipeline_jobs`: List jobs belonging to a specific pipeline 
- `jobs_describe`: Describes a job, surfacing agent details, and lifecycle timestamps
- `jobs_logs`: Fetches job logs. For cloud jobs, it streams loghub events. For self-hosted jobs, returns a URL where logs can be fetched
- `get_test_results`: Returns a signed URL (gzip JSON) for JUnit-style [test reports](../tests/test-reports). Response includes URL, path, compression, and fetch instructions.

The following tools require MCP Server write permissions in your organization. Contact `support@semaphore.io` to enable this feature.

- `workflow_run`: Schedules a new workflow to be executed
- `workflow_rerun`: Reruns an existing workflow with the original parameters

See [example prompts](#examples) to see a bit of what's possible.

## Configure your AI Agent or IDE

Access to the MCP Server is controlled via an API Token. You can obtain your API token in two ways:

- [Personal API Token](../user-management#profile-token): if you don't know your personal API token, you can reset it and obtain a new one
- [Service Account](../service-accounts): create a service account with *Member* role and use its API token

Both types of tokens are used to communicate with the Semaphore MCP Server endpoint: `https://mcp.semaphoreci.com/mcp`

If you have problems connecting to the MCP Server, see [troubleshooting](#troubleshooting).


### Claude Code {#claude-code}

<Steps>

1. Export an environment variable with your API token

    ```shell
    export SEMAPHORE_API_TOKEN=my-token
    ```

2. Add the MCP Server to Claude Code

    ```shell
    claude mcp add semaphore https://mcp.semaphoreci.com/mcp \
      --scope user --transport http \
      --header "Authorization: Bearer $SEMAPHORE_API_TOKEN"
    ```

3. If you have a session open, restart Claude Code

4. Open a terminal and navigate to your repository

5. Start **Claude Code** and run the following command to update `CLAUDE.md` and add Semaphore project details to the repository. This step is optional but recommended to speed up AI tasks and reduce token usage

    ```shell title="Initialize Claude configuration for MCP"
    /semaphore:mcp_setup (MCP) your-project-name your-semaphore-organization
    ```

    :::note

    If you get an error stating `strategy requires thinking to be enabled`. This error is caused by [known bug](https://github.com/anthropics/claude-code/issues/11231) in Claude Code.

    The workaround is to add `ultrathink` to the previous command:
    
    ```shell title="Initialize Claude configuration for MCP"
    /semaphore:mcp_setup (MCP) your-project-name your-semaphore-organization ultrathink
    ```

    :::

</Steps>

### OpenAI's Codex {#codex}

<Steps>

1. Open `$HOME/.codex/config.toml` and add the following lines to the config file


    ```toml title="Semaphore MCP Configuration for Codex"
    [mcp_servers.semaphore]
    url = "https://mcp.semaphoreci.com/mcp"
    bearer_token_env_var = "SEMAPHORE_API_TOKEN"
    startup_timeout_sec = 30
    tool_timeout_sec = 300
    ```

    :::note Environment variable name

    The `bearer_token_env_var` value references the name of the environment variable that contains the actual API token value. It *is not* set to the actual API token value.

    :::

2. Export an environment variable with your API token. The *name of the environment variable* must be equal to the `bearer_token_env_var` in the previous step. Consider adding this line to your `.bashrc` (or similar)

    ```shell
    export SEMAPHORE_API_TOKEN=my-token
    ```

3. Start Codex normally

</Steps>

### VSCode Codex Extension {#vscode-codex}

<Steps>

1. Install the [VSCode Codex Extension](https://developers.openai.com/codex/ide/)

2. Set up Codex as shown [above in OpenAI's Codex](#codex). Alternatively, in VS Code press the Gear icon → **MCP settings** → **Open config.toml** and add the lines shown in the [Codex Setup](#codex)

    ```toml title="Semaphore MCP Configuration for Codex"
    [mcp_servers.semaphore]
    url = "https://mcp.semaphoreci.com/mcp"
    bearer_token_env_var = "SEMAPHORE_API_TOKEN"
    startup_timeout_sec = 30
    tool_timeout_sec = 300
    ```

3. Close VS Code

4. Export an environment variable with your API token. The *name of the environment variable* must be equal to the `bearer_token_env_var` in the `config.toml`. Consider adding this line to your `.bashrc` (or similar)

    ```shell
    export SEMAPHORE_API_TOKEN=my-token
    ```

5. Start VS Code from the command line, in the same shell session where you set the environment variable. This ensures VS Code can have access to the API token

    ```shell
    code path/to/project
    ```

    :::note

      Due to current limitations of the Codex extension for VS Code, if you start VS Code in any other way except from the terminal session where the SEMAPHORE_API_TOKEN variable has the correct value, the Semaphore MCP server **will not work**.

    :::


</Steps>

## Example Prompts {#examples}

See the [MCP Usage Examples](./mcp-usage-examples) for example use cases for the MCP server with a complete explanation of internals.

## Troubleshooting {#troubleshooting}

### Codex fails to connect

**Symptom**: When you start Codex, you see the following message:

```text
■ MCP client for `semaphore` failed to start: handshaking with MCP server failed: Send message error Transport
[rmcp::transport::worker::WorkerTransport<rmcp::transport::streamable_http_client::StreamableHttpClientWorker<reqwest::async_impl::client::Client>>] error:
Client error: HTTP status client error (401 Unauthorized) for url (https://mcp.semaphoreci.com/mcp), when send initialize request
```

**Solution**: This usually means the environment variable with the Semaphore API Token is not correctly loaded. Check your `config.toml` to learn what the environment variable name and ensure you are setting it correctly in your shell before starting Codex.


### VS Code fails to connect

**Symptom**: Your Codex extension in VS Code fails to connect with the MCP server.

**Solution**: This usually means that VS Code does not have access to the environment variable with the Semaphore API Token. Ensure you have set the environment variable as per `config.toml` in your shell, and that you are actually starting VS Code from that very same shell session. Starting VS Code by any other means causes Codex to fail the connection.

## See also

- [User management](../user-management)
- [Service accounts](../service-accounts)
- [MCP Usage Examples](./mcp-usage-examples)
- [Self-healing CI](./self-healing-ci)
- [Copilot Cloud Integration](./copilot-agent-cloud)




