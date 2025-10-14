# mcp_server

The `mcp_server` service is a minimal Model Context Protocol (MCP) server implemented with [github.com/mark3labs/mcp-go](https://github.com/mark3labs/mcp-go). It boots an MCP server that exposes a single `echo` tool and communicates over stdio so it can be embedded in MCP-compatible clients.

## Requirements

- Go 1.23 (toolchain `go1.23.8` is configured in `go.mod`)
- Run `go mod tidy` once to download dependencies.

## Running

```bash
cd mcp_server
go run ./cmd/mcp_server -http :8080
```

By default the server advertises itself as `semaphore-echo` and serves the MCP streamable HTTP transport on `:8080`. The single `echo` tool returns the supplied `message` parameter verbatim in the response.

Use `-version` to print the current implementation version, `-name` to override the advertised implementation identifier, or `-http` to change the listening address.

## Docker

Build the container image:

```bash
cd mcp_server
docker build -t semaphore-mcp-server .
```

Run it locally (listening on port 8080):

```bash
docker run --rm -p 8080:8080 semaphore-mcp-server
```
