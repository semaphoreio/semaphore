# RepositoryHub

As the name suggests, RepositoryHub is the service for managing repositories on
SemaphoreCI. If it's related to repositories, just ask RepositoryHub.

In addition communication with git platforms(GitHub, GitLab, BitBucket) happens here.

## Docs

- [Webhooks](docs/webhooks.md)

## Development

If you are using `vscode` I suggest taking a look at [developing inside a container](https://code.visualstudio.com/docs/remote/containers).

One can use the following base configuration:

```json
// .devcontainer/devcontainer.json
{
  "name": "App",
  "dockerComposeFile": ["../docker-compose.yml", "docker-compose.yml"],
  "service": "app",
  "workspaceFolder": "/workspace/repository_hub",
  "settings": {},
  "extensions": [
    "jakebecker.elixir-ls",
    "samuel-pordeus.elixir-test",
    "pantajoe.vscode-elixir-credo",
    "yo1dog.cursor-align",
    "wmaurer.change-case",
    "ms-vscode.cmake-tools",
    "formulahendry.code-runner",
    "pgourlain.erlang",
    "knisterpeter.vscode-github",
    "github.copilot",
    "github.vscode-pull-request-github",
    "eamodio.gitlens",
    "ms-azuretools.vscode-docker",
    "vivaxy.vscode-conventional-commits"
  ]
}
```

```yaml
# .devcontainer/docker-compose.yml
version: '3.6'
services:
  app:
    volumes:
      - ..:/workspace
      - ../.semaphore:/workspace/repository_hub/.semaphore:delegated
    command: /bin/sh -c "while sleep 1000; do :; done"
    environment:
      MIX_ENV: test
```

### Testing

Run `make test`

### Shell

Run `make bash` to start a bash session in the container. The port is picked randomly to avoid conflicts with the host.
To see which port was selected, use `docker port repository_hub_bash`.
