# Semaphore Monorepo Guidance

- Semaphore is the open-source CI/CD platform; this monorepo contains Go microservices, Elixir/Phoenix applications, Node/TypeScript frontends, Helm charts, and shared tooling.
- Root documentation lives in `README.md`, `DEVELOPMENT.md`, `LOCAL-DEVELOPMENT.md`, and `docs/`. Consult the service-level README or `AGENTS.md` before making changes inside any service directory.
- Major service roots include Go modules such as `artifacthub/`, `bootstrapper/`, `encryptor/`, and `public-api-gateway/`; Elixir apps such as `front/`, `guard/`, and `public-api/v1alpha/`; and infrastructure assets in `helm-chart/`, `skaffold.yaml`, `scripts/`, and `security-toolbox/`.
- The shared top-level `Makefile` is included from each service-specific `Makefile`; standard targets (`build`, `test`, `lint`, `format`, `check.*`) are consistent across services. Prefer those wrappers over ad-hoc commands so CI sees the same steps.

## Build & Validation Workflow

- Run inside the provided Docker/dev-container flow (`DEVELOPMENT.md`). Enable BuildKit (`export DOCKER_BUILDKIT=1`) before invoking make targets that build images.
- Typical local loop:
  1. Install deps once (`mix deps.get`, `npm install --prefix assets`, or `go mod tidy`) from within the service directory.
  2. `make build` (Elixir services set `MIX_ENV`, Go services build via Docker Compose) to ensure containers compile.
  3. Execute tests (`make test.ex`/`mix test` for Elixir, `make test`/`go test ./...` for Go, `npm test --prefix assets` for JS). Use the provided `TEST_FILE`/`TEST_FLAGS` variables when narrowing Elixir suites.
  4. Keep quality gates green: `mix format`, `mix credo --strict`, `mix dialyzer` (run after `mix deps.get && mix compile`), `make lint` (Go uses `revive`), `npm run lint`.
  5. Run security/tooling checks as needed (`make check.ex.deps`, `make check.go.deps`, `make check.docker`, `make check.generate-report`).
- Generated clients (for example, protobuf stubs under `lib/internal_api` or `include/internal_api`) must be regenerated with the service `make pb.gen` target rather than edited by hand.
- For end-to-end validation or demos, follow `LOCAL-DEVELOPMENT.md` to launch the Minikube/Skaffold environment (8 CPUs, 16 GB RAM, mkcert-generated TLS). Note any manual adjustments you make so future runs are repeatable.
- Keep a record of the exact commands executed while validating your change and quote them in your PR; CI mirrors these make targets.

## Service-Specific Guidance

- Always read the nearest `AGENTS.md` before modifying a service; current examples live at `front/AGENTS.md`, `guard/AGENTS.md`, and `public-api/v1alpha/AGENTS.md`. These documents explain layout, command sequences, and coding expectations that override generic defaults.
- Path-specific Copilot instructions live under `.github/instructions/`. When working in `public-api/v1alpha`, follow `.github/instructions/public-api-v1alpha.instructions.md` in tandem with that service's `AGENTS.md`.
- If a service lacks an `AGENTS.md`, add one alongside your change so future contributors have a canonical reference.

## Working Norms

- Follow the Conventional Commit style already in use (`type(scope): summary`) and keep commits focused. Mention Helm/config follow-ups in the PR body when applicable.
- Update documentation, fixtures, and charts that depend on the changed behaviour. For API changes, synchronise examples in `docs/` and contract fixtures under `test/fixture`.
- Prefer deterministic tests; leverage existing factories and mocks rather than hitting external services directly. Tag long-running suites appropriately.
- Trust these instructions (and the service `AGENTS.md` files) first. Only resort to ad-hoc code search or experimentation when the documented steps are insufficient or incorrect.
