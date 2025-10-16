# Repo Proxy Referent Agent Notes

## Key Files
- `lib/repo_proxy_ref/grpc/server.ex` – canned responses for `Describe` and `CreateBlank` calls.
- `lib/repo_proxy_ref/grpc/health_check.ex` – gRPC health endpoint.
- `config/*.exs` – port, TLS, and logging configuration for the stub.

## Commands
- Setup deps: `cd repo_proxy_ref && mix deps.get` (or `mix setup`).
- Run tests: `mix test`.
- Start stub locally: `iex -S mix` (defaults to the port in config; override with `REPO_PROXY_REF_PORT`).
- Smoke test: `grpcurl -plaintext localhost:<port> InternalApi.RepoProxy.RepoProxyService.Describe -d '{"hook_id":"master"}'`.

## Debug Tips
- Scenario selection is driven by `hook_id` (describe) and `request_token` (create_blank). Inspect matches in `server.ex` when adding new fixtures.
- Timeout simulations use `:timer.sleep/1`; adjust durations if tests get flaky.
- Protobuf structs are built with `Util.Proto.deep_new!`; mismatched fields usually mean the proto dependency is outdated.
- Search logs with `tag:repo_proxy_ref` (LogTee) to correlate requests during plumber runs.

## Extending
- Add new canned repo states by updating helper functions (`mock_repo/1`, `mock_hook/1`).
- Keep commit SHA generation deterministic if tests assert on values.
- Update tests under `test/` whenever you add or change scenarios.
