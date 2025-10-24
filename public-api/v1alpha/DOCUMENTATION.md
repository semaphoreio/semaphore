# Repository Architecture Notes

## Service Purpose & Entry Points
Pipelines API is the public HTTP façade for Semaphore’s Pipelines domain. It receives REST requests, validates them, and forwards calls to internal gRPC services such as Pipelines, Workflows, Deployments, RBAC, and SecretHub. The OTP entry point is `lib/pipelines_api/application.ex`, which starts a `Plug.Cowboy` endpoint on port 4004, initialises feature providers, and warms two `Cachex` caches (`:feature_provider_cache`, `:project_api_cache`).

## Request Flow & Runtime Stack
- HTTP traffic lands in `lib/pipelines_api/router.ex`, a `Plug.Router` that wires every route to a domain-specific module (e.g., `PipelinesAPI.Pipelines.Describe`).
- Domain modules follow a consistent pattern: parse params, call into a `*_client` module, and reply via helpers in `PipelinesAPI.Pipelines.Common` or a domain-specific responder. Success and error tuples map to HTTP status automatically.
- Authentication/authorization gates live in the RBAC and Feature clients; there are no custom Plug modules today (`lib/pipelines_api/plugs/` is intentionally empty).
- Long-running gRPC calls run inside `Wormhole.capture` to enforce timeouts defined in `config/config.exs`. Metrics flow through `PipelinesAPI.Util.Metrics` into Watchman/StatsD (`watchman` config block).

## Directory Map
- `lib/pipelines_api/pipelines`, `workflows`, `deployments`, `schedules`, `self_hosted_agent_types`, etc.: HTTP handlers grouped by resource. Files mirror verbs (`list.ex`, `describe.ex`, `terminate.ex`).
- `lib/pipelines_api/*_client/`: Each client encapsulates gRPC glue with submodules for request formatting, the actual gRPC stub wrapper, and response shaping. Single-file clients (e.g., `jobs_client.ex`) follow the same tuple contract.
- `lib/internal_api/`: Generated gRPC stubs. Regenerate via `make pb.gen`, which clones `renderedtext/internal_api` and runs `scripts/internal_protos.sh`.
- `config/`: Compile-time (`config.exs`) and runtime (`runtime.exs`) settings. `config/test.exs` shortens gRPC and Wormhole timeouts; `config/dev.exs` points metrics to the local StatsD agent.
- `test/support/`: Shared stubs and fake services. `Support.FakeServices` boots `GrpcMock` servers on port 50052 so unit tests never hit production systems.
- `scripts/`: `internal_protos.sh` for protobuf regeneration and `vagrant_sudo` helper for privileged Docker commands.

## External Integrations
- Environment variables in `Makefile` and `docker-compose.yml` provide endpoints (`PPL_GRPC_URL`, `LOGHUB_API_URL`, `FEATURE_GRPC_URL`, etc.). Override them when connecting to non-default clusters.
- Feature flags are served by a remote Feature Hub unless `ON_PREM=true`, in which case a YAML provider is loaded with `FEATURE_YAML_PATH`.
- Response pagination goes through `Scrivener.Headers`, which rewrites paths to `/api/<API_VERSION>/…` before responses leave the service.

## Development & Diagnostics Workflow
- `make console` launches the Docker dev container with dependencies and shares `_build`/`deps` for fast recompiles.
- From inside the container: start the API via `iex -S mix`. Health probes hit `/` or `/health_check/ping`.
- Format and lint with `mix format` and `mix credo --strict`. Optional type checks come from `mix dialyzer` once PLTs are cached.
- Run suites with `make unit-test` or `mix test --cover`. The custom ExUnit formatter writes JUnit XML reports under `./out/test-reports.xml`.
- To inspect gRPC traffic locally, tail logs produced by `PipelinesAPI.Util.Log` or enable DEBUG by exporting `LOG_LEVEL=debug` before boot.

## Testing Infrastructure
- Tests rely heavily on support factories (`test/support/stubs.ex`, `test/support/factories.ex`) to fabricate workflows, pipelines, and users.
- `GrpcMock` doubles are registered for every dependency (SecretHub, Gofer, Pipeline, ProjectHub, etc.) in `Support.FakeServices.init/0`.
- When adding new gRPC calls, extend the relevant mock to cover the new RPC and update helper stubs so fixtures stay meaningful.

## Common Change Playbooks
1. **Add or adjust an endpoint**: Update `router.ex`, create/modify the domain module under `lib/pipelines_api/<resource>/`, and ensure responses return `{status, payload}` tuples through the common helper.
2. **Add a gRPC call**: Touch the appropriate `*_client` directory—update the RequestFormatter, extend the `GrpcClient` wrapper, and cover ResponseFormatter cases. Regenerate protobuf stubs if the contract changed.
3. **Introduce feature-flagged behaviour**: Depend on the provider returned from `Application.get_env(:pipelines_api, :feature_provider)`, and store expensive lookups in Cachex to match existing patterns.
4. **Regenerate protobufs**: Run `make pb.gen`, commit resulting changes under `lib/internal_api`, and verify no manual edits are lost.
5. **Triage production incidents**: Use `/logs/:job_id` for streaming logs, `/troubleshoot/*` endpoints for aggregated context, inspect Watchman metrics for latency spikes, and confirm caches or feature toggles aren’t stale.

Keep this document nearby when picking up new tasks—most flows follow the patterns above, so identifying the right directory or client is usually the quickest path to a fix.
