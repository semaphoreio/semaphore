# Repository Guidelines

## Project Structure & Module Organization
Semaphore is a polyglot monorepo. Core Elixir services (`auth/`, `guard/`, `projecthub/`) keep runtime code in `lib/` with ExUnit suites in `test/`. Go utilities such as `bootstrapper/`, `repohub/`, and this `mcp_server/` follow the `cmd/` (entrypoints) and `pkg/` (libraries, generated protobufs) layout. The Phoenix/React frontend lives in `front/` with assets under `front/assets/`. Shared documentation resides in `docs/` and `rfcs/`, and enterprise-only modules live in `ee/`.

## Build, Test, and Development Commands
Use `make build` at the repo root to produce Docker images. Run Elixir suites with `make test.ex` or target a file via `make test.ex TEST_FILE=test/<path>.exs`. Go packages (including `mcp_server`) rely on `make test` (`go test ./...`) and `make lint` for `go vet` plus static checks. Frontend bundles run through `make test.js`. For a local UI, start `make dev.server`; `LOCAL-DEVELOPMENT.md` covers Minikube and dev-container workflows.

## Coding Style & Naming Conventions
Elixir modules use PascalCase with snake_case filenames; tests end in `_test.exs`. Go packages stay lowercase, with table-driven `_test.go` suites. React components prefer PascalCase filenames. Formatters and linters are mandatory before commits: `make format.ex` for Elixir, `make lint` for Go, and `make lint.js` for frontend assets. Share helpers through `test/support/` instead of duplicating utilities.

## Testing Guidelines
Elixir services use ExUnit with focused `describe` blocks; add `--only integration` for slower suites. Go code should include regression cases when bugfixing; run `go test ./...` (and `go test -race ./...` when touching concurrency paths). Frontend updates require `make test.js`. Align Phoenix endpoint changes with their paired ExUnit suites.

## Commit & Pull Request Guidelines
Follow Conventional Commits (e.g., `feat(auth):`, `fix(front):`, `docs:`) and keep scopes tight. Summaries must state rationale and risk. Before opening a PR, ensure formatters, linters, and relevant `make test*` targets pass. Link issues where available and attach screenshots or logs for UI or automation changes.

## Security & Configuration Tips
Surface dependency issues early with `make check.ex.deps`, `make check.go.deps`, and `make check.docker`. Store secrets in local `.env` files; never commit credentials. Runtime configuration reads internal gRPC endpoints from `INTERNAL_API_URL_PLUMBER`, `INTERNAL_API_URL_JOB`, `INTERNAL_API_URL_LOGHUB`, and `INTERNAL_API_URL_LOGHUB2`, falling back to legacy `MCP_*` variables. Export `DOCKER_BUILDKIT=1` to mirror CI Docker builds.

## MCP Tool Metrics Quickstart
- Shared instrumentation lives in `pkg/tools/internal/shared/metrics.go`. Inside every MCP tool handler, create a tracker with `tracker := shared.TrackToolExecution(ctx, "<tool_name>", orgID)`, `defer tracker.Cleanup()`, and call `tracker.MarkSuccess()` right before you return a successful result.
- Organization tags resolve via `pkg/tools/internal/shared/org_resolver.go`. The resolver is configured once through `tools.ConfigureMetrics(provider)` during server bootstrap, so new tools only need to supply the org ID (or `""` when not applicable).
- For org-agnostic tools (e.g., `organizations_list`), pass an empty org ID so we still emit `count_*` and `duration_ms` metrics without tags.
- Following this pattern ensures every tool automatically publishes `tools.<tool_name>.count_total|count_passed|count_failed` and `tools.<tool_name>.duration_ms` metrics, with human-readable org tags whenever available, keeping dashboards consistent without extra boilerplate.
