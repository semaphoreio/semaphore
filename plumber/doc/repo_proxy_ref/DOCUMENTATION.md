# Repo Proxy Referent

## Overview
`repo_proxy_ref` is a lightweight gRPC stub that mimics the external Repo Proxy service used during integration tests and local development. It serves deterministic responses for `Describe` and `CreateBlank` RPCs so plumber components can exercise promotion and scheduling flows without contacting the real repo-proxy.

## Responsibilities
- Implement `InternalApi.RepoProxy.RepoProxyService` with canned responses covering happy-path, timeout, and error scenarios.
- Provide synthetic hook metadata (branch, PR, tag cases) for pipelines under test.
- Generate commit SHAs and repo details expected by downstream services when they schedule pipelines or fetch YAML from repositories.

## Architecture
- `RepoProxyRef.Application` boots a gRPC server (`GRPC.Server.Supervisor`) exposing `RepoProxyRef.Grpc.Server` and `RepoProxyRef.Grpc.HealthCheck`.
- `RepoProxyRef.Grpc.Server` matches incoming `hook_id` / `request_token` values to predefined behaviours:
  - `hook_id: "timeout"` / `request_token: "timeout"` simulate slow dependencies.
  - `hook_id: "bad_param"` returns `BAD_PARAM` codes.
  - Standard IDs return OK payloads built with helper functions.
- Responses are constructed via `Util.Proto.deep_new!/2`, ensuring they stay aligned with protobuf definitions.

## Usage Patterns
- Docker compose and test suites start the referent alongside plumber to isolate repo-proxy interactions.
- When running plumber locally, exporting `REPO_PROXY_URL` to point at the referent gRPC endpoint allows schedule/describe flows to proceed without external dependencies.
- The service also acts as a fixture provider for scenario-specific commits (`10_schedule_extension`, `14_free_topology_failing_block`, etc.).

## Operations
- Install deps & compile: `cd repo_proxy_ref && mix deps.get && mix compile` (or `mix setup`).
- Run tests: `mix test` (validates gRPC handlers and health check).
- Start locally: `iex -S mix` (listens on port configured in `config/config.exs`).
- Health check: use `grpcurl -plaintext localhost:<port> grpc.health.v1.Health/Check`.

## Extending
- Add new canned scenarios by updating pattern matches in `RepoProxyRef.Grpc.Server` and adjusting tests under `test/`.
- Keep protobuf dependency (`proto` app) up to date to avoid type mismatches.
- Ensure new mock data mirrors real repo-proxy contracts (branch names, commit ranges, repository IDs).
