# Repository Guidelines

## Project Structure & Module Organization
Semaphore’s monorepo mixes Elixir services (`auth/`, `guard/`, `projecthub/`), Go tooling (`bootstrapper/`, `repohub/`), and the Phoenix/React UI in `front/`. Elixir services keep source in `lib/` and ExUnit suites in `test/`. Go utilities follow the `cmd/` entrypoint with reusable code under `pkg/`. Frontend assets, including React components and bundles, live in `front/assets/`. Shared documentation sits in `docs/` and `rfcs/`, while enterprise-specific code is isolated under `ee/`.

## Build, Test, and Development Commands
Run commands from the relevant service directory. Use `make build` to produce Docker images for CI parity. Execute `make test.ex` (or `make test.ex TEST_FILE=test/<path>.exs`) to run ExUnit suites. For Go modules, run `make test` (`go test ./...`) and add `-race` when debugging concurrency. Frontend checks run through `make test.js`. Start the Phoenix UI locally with `make dev.server`, and consult `LOCAL-DEVELOPMENT.md` for Minikube or dev-container workflows.

## Coding Style & Naming Conventions
Elixir modules are PascalCase with files in snake_case; tests end in `_test.exs`. Go packages stay lowercase, with exported identifiers PascalCase. React components use PascalCase filenames inside `front/assets/`. Before committing, run `make format.ex`, `make lint` for Go format and static checks, and `make lint.js` for ESLint/Prettier to keep the tree consistent.

## Testing Guidelines
Favor focused ExUnit `describe` blocks and use tags such as `--only integration` for longer suites. Keep Go tests table-driven in `_test.go` files. Frontend changes require Jest coverage via `make test.js`. Add regression tests alongside fixes and align Phoenix endpoint updates with matching ExUnit cases.

## Commit & Pull Request Guidelines
Commits follow Conventional Commits, e.g., `feat(auth): add token audit trail`. PRs should explain rationale, outline risk, and link issues when available. Include screenshots or logs for UI or automation changes, and confirm formatters, linters, and relevant `make test*` targets have passed before requesting review.

## Security & Configuration Tips
Run `make check.ex.deps`, `make check.go.deps`, and `make check.docker` regularly to catch dependency and image issues. Keep secrets in local `.env` files referenced by docker-compose, never checked into the repository, and export `DOCKER_BUILDKIT=1` for reproducible Docker builds. For deeper architectural context, review `DOCUMENTATION.md`.
