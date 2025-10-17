# mcp_server

The `mcp_server` service is a Model Context Protocol (MCP) server implemented with [github.com/mark3labs/mcp-go](https://github.com/mark3labs/mcp-go). It exposes Semaphore workflow, pipeline, and job data to MCP-compatible clients.

## Contributor Guide

Refer to [`AGENTS.md`](AGENTS.md) for repository guidelines, project structure, and development workflows.

## Exposed tools

| Tool | Description |
| ---- | ----------- |
| `echo` | Returns the provided `message` verbatim (handy for smoke tests). |
| `workflows_list` | Lists workflows for a project using keyset pagination. |
| `pipelines_list` | Lists pipelines for a workflow, including state/result metadata. |
| `pipelines_describe` | Describes a pipeline and its blocks (optionally detailed). |
| `jobs_describe` | Describes a job, surfacing agent details and lifecycle timestamps. |
| `jobs_logs` | Fetches job logs. Hosted jobs stream loghub events; self-hosted jobs mint a Loghub2 pull token. |

## Requirements

- Go 1.24 (toolchain `go1.24.9` is configured in `go.mod`).
- SSH access to `renderedtext/internal_api` for protobuf generation.

## Generating protobuf stubs

The server consumes internal gRPC definitions. Generate (or refresh) the Go descriptors whenever the protos change:

```bash
cd mcp_server
make pb.gen INTERNAL_API_BRANCH=master
```

`make pb.gen` clones `renderedtext/internal_api` and emits Go code under `pkg/internal_api/`. The generated files are required for builds—remember to commit them after regeneration.

## Configuration

The server dials internal gRPC services based on environment variables. Deployment defaults come from the `INTERNAL_API_URL_*` ConfigMap entries; legacy `MCP_*` variables and historical endpoints remain as fallbacks.

| Purpose | Environment variables (first non-empty wins) |
| ------- | -------------------------------------------- |
| Workflow gRPC endpoint | `INTERNAL_API_URL_PLUMBER`, `MCP_WORKFLOW_GRPC_ENDPOINT`, `WF_GRPC_URL` |
| Pipeline gRPC endpoint | `INTERNAL_API_URL_PLUMBER`, `MCP_PIPELINE_GRPC_ENDPOINT`, `PPL_GRPC_URL` |
| Job gRPC endpoint | `INTERNAL_API_URL_JOB`, `MCP_JOB_GRPC_ENDPOINT`, `JOBS_API_URL` |
| Loghub gRPC endpoint (hosted logs) | `INTERNAL_API_URL_LOGHUB`, `MCP_LOGHUB_GRPC_ENDPOINT`, `LOGHUB_API_URL` |
| Loghub2 gRPC endpoint (self-hosted logs) | `INTERNAL_API_URL_LOGHUB2`, `MCP_LOGHUB2_GRPC_ENDPOINT`, `LOGHUB2_API_URL` |
| Dial timeout | `MCP_GRPC_DIAL_TIMEOUT` (default `5s`) |
| Call timeout | `MCP_GRPC_CALL_TIMEOUT` (default `15s`) |

Hosted jobs require `loghub` to be reachable. Self-hosted jobs require `loghub2`. Missing endpoints yield structured MCP errors from the relevant tools.

## Running locally

```bash
cd mcp_server
make pb.gen           # only needed after proto updates
go run ./cmd/mcp_server -http :3001
# or: make dev.run     # launches with stubbed responses on :3001
```

The server advertises itself as `semaphore-echo` and serves the MCP Streamable HTTP transport on `:3001`. Health probes remain on `GET /readyz` and `GET /healthz`. Use `-version` to print the binary version, `-name` to override the advertised implementation identifier, or `-http` to change the listening address.

### Development stubs

When you just want to exercise the MCP tools without wiring real services, export `MCP_USE_STUBS=true` before starting the server. The process will skip gRPC dialing and respond with deterministic in-memory data for workflows, pipelines, jobs, and logs.

```bash
export MCP_USE_STUBS=true
go run ./cmd/mcp_server
# or: make dev.run
```

Disable the variable (or set it to anything other than `true`) to talk to real internal APIs again.

> Tip: when [`air`](https://github.com/cosmtrek/air) is installed, `make dev.run` automatically enables hot reloading using `.air.dev.toml`; otherwise it falls back to `go run`.

## Docker

Build the container image:

```bash
cd mcp_server
docker build -t semaphore-mcp-server .
```

Run it locally (listening on port 3001):

```bash
docker run --rm -p 3001:3001 \
  -e INTERNAL_API_URL_PLUMBER=ppl:50053 \
  -e INTERNAL_API_URL_JOB=semaphore-job-api:50051 \
  -e INTERNAL_API_URL_LOGHUB=loghub:50051 \
  -e INTERNAL_API_URL_LOGHUB2=loghub2-internal-api:50051 \
  semaphore-mcp-server
```
