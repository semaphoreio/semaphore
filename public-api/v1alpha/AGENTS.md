# Repository Guidelines

## Project Structure & Module Organization
Source lives in `lib/pipelines_api`, which exposes HTTP controllers that call internal gRPC clients. Regenerated gRPC stubs sit in `lib/internal_api`; rerun `make pb.gen` instead of editing them. Environment configuration is under `config/*.exs` (overrides in `config/runtime.exs`). Shared scripts live in `priv/script`, Helm assets in `helm/`, and ExUnit fixtures in `test/` plus `test/support`.

## Build, Test, and Development Commands
Use `make console.ex` (or `make console.bash`) from `public-api/v1alpha` to enter the Docker dev container with dependencies mounted. Start the server via `iex -S mix` inside that shell; it binds to port 4004 per `docker-compose.yml`. Run the suite through `make test.ex` (docker-compose) or `mix test` inside the container. Build images with `make build MIX_ENV=prod`; add `DOCKER_BUILD_PROGRESS=plain` in non-TTY environments and `NO_BUILD_CACHE=true` if cache imports fail. Refresh dependencies with `mix deps.get`, and enforce formatting with `mix format`. Static analysis helpers include `mix credo --strict` and `mix dialyzer` (after `mix deps.get && mix compile`).

## Coding Style & Naming Conventions
Stick to idiomatic Elixir: two-space indentation, pipeline-friendly code, and one module per file (e.g. `lib/pipelines_api/web/router.ex` for `PipelinesAPI.Web.Router`). Run `mix format` before opening a PR; `.formatter.exs` defines the inputs. Let Credo guide readability—fix warnings rather than ignoring them. Prefer descriptive atoms, snake_case for functions, PascalCase for modules, and add concise `@moduledoc` notes to complex modules.

## Testing Guidelines
The project uses ExUnit with helpers in `test/support`. Place new suites under `test/`, mirroring the source path, and name files `_test.exs`. Run `mix test --cover` when touching request or authorization logic to watch coverage. For gRPC integrations, lean on `GrpcMock` rather than real services. Keep tests deterministic by stubbing network calls and timestamps with `Faker` or recorded fixtures.

## Commit & Pull Request Guidelines
Follow the Conventional Commits pattern seen in history (`type(scope): summary`), using scopes such as `secrethub` or `docs` to clarify impact. Keep commits focused and include test or lint updates when relevant. Pull requests must describe the scenario, list impacted gRPC endpoints, and note any Helm or config follow-up. Link tracking issues, call out breaking changes, and include the latest `mix test` or `mix credo` output before requesting review.

## Security & Configuration Tips
Environment defaults live in the Makefile and `docker-compose.yml`; override gRPC endpoints via variables like `LOGHUB_API_URL` or `API_VERSION`. Container scans use the security toolbox (`make check.docker MIX_ENV=prod`) and write reports to `public-api/v1alpha/out/`. Never hardcode secrets—use the provided env vars or the helpers in `lib/pipelines_api/secrets`. When updating protobuf definitions, ensure regenerated clients do not expose new fields without matching authorization checks in the HTTP layer.
