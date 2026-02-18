# Overview
- BranchHub is an Elixir service that manages branches and exposes gRPC endpoints for describe/list/find-or-create/archive. See: `branch_hub/README.md`, `branch_hub/lib/branch_hub/server.ex`
- Persistence uses Ecto with Postgres and a `branches` table. See: `branch_hub/lib/branch_hub/model/branches.ex`, `branch_hub/priv/repo/migrations/20210906124818_add_branches_table.exs`
- Supported runtime versions: Elixir `~> 1.12` (Mix), Docker base uses Elixir 1.13.4 + OTP 24.2.2 on Alpine 3.22.2. See: `branch_hub/mix.exs`, `branch_hub/Dockerfile`

# Golden Rules (Must Follow)
- Run formatter and Credo before PRs: `make format.ex` and `make lint.ex` (CI QA runs both). See: `Makefile`, `.semaphore/semaphore.yml`
- Run tests with `make test.ex` (CI QA runs tests). See: `Makefile`, `.semaphore/semaphore.yml`
- When changing DB schema, add Ecto migrations under `priv/repo/migrations` and ensure `mix ecto.create, ecto.migrate` succeeds in test setup. See: `branch_hub/priv/repo/migrations/20210906124818_add_branches_table.exs`, `branch_hub/Makefile`
- When protobuf APIs change, regenerate stubs with `make pb.gen`. See: `branch_hub/Makefile`, `branch_hub/scripts/internal_protos.sh`

# Repo Map (High Level)
- `branch_hub/config/` holds compile/runtime config (`config.exs`, `dev.exs`, `test.exs`, `prod.exs`, `runtime.exs`). See: `branch_hub/config/config.exs`
- `branch_hub/lib/branch_hub/` contains the OTP app and gRPC server; main entrypoints are `BranchHub.Application` and `BranchHub.Server`. See: `branch_hub/lib/branch_hub/application.ex`, `branch_hub/lib/branch_hub/server.ex`
- `branch_hub/lib/branch_hub/model/` contains the schema and query layer. See: `branch_hub/lib/branch_hub/model/branches.ex`, `branch_hub/lib/branch_hub/model/branches_queries.ex`
- `branch_hub/lib/internal_api/` contains generated protobuf modules. See: `branch_hub/lib/internal_api/branch.pb.ex`
- `branch_hub/priv/repo/migrations/` stores Ecto migrations. See: `branch_hub/priv/repo/migrations/20210906124818_add_branches_table.exs`
- `branch_hub/test/` contains ExUnit tests for server and query logic. See: `branch_hub/test/branch_hub/server_test.exs`, `branch_hub/test/branch_hub/model/branches_queries_test.exs`
- `branch_hub/helm/` holds the Helm chart and deployment template. See: `branch_hub/helm/Chart.yaml.in`, `branch_hub/helm/templates/deployment.yaml`
- `branch_hub/Dockerfile`, `branch_hub/docker-compose.yml`, and `branch_hub/Makefile` define build/run/test tooling (root `Makefile` is included). See: `branch_hub/Makefile`, `Makefile`

# Build, Run, Test
- Build the image locally: `make build` (uses Docker build targets from root Makefile). See: `Makefile`, `branch_hub/Makefile`
- Run an interactive IEx shell in the container: `make console.ex`. See: `Makefile`
- Run locally with Docker Compose: `docker compose up` (uses `mix run --no-halt` from compose). See: `branch_hub/docker-compose.yml`
- Run tests: `make test.ex` (sets `MIX_ENV=test`, runs `mix ecto.create, ecto.migrate`, then `mix test`). See: `Makefile`, `branch_hub/Makefile`
- Fast path for a single test file: `make test.ex FILE=path/to_test.exs` (passes `FILE`/`FLAGS` to `mix test`). See: `Makefile`
- CI summary for BranchHub: builds test/prod images, runs QA (`make format.ex`, `make lint.ex`, `make test.ex`), and runs security checks (`make check.ex.code`, `make check.ex.deps`, `make check.docker`). See: `.semaphore/semaphore.yml`, `Makefile`
- README lists `make dev.setup`, `make deps.check`, `make format.check`, and `make lint`, but those targets are not defined in `branch_hub/Makefile` or `Makefile`. Unknown / verify. See: `branch_hub/README.md`, `branch_hub/Makefile`, `Makefile`

# Coding Conventions
- Formatting uses `mix format` inputs from `.formatter.exs` (`config`, `lib`, `test`, mix files). See: `branch_hub/.formatter.exs`
- Credo runs in strict mode, max line length 120, and ignores generated `*.pb.ex` files. See: `branch_hub/.credo.exs`
- gRPC handlers build responses with `InternalApi.ResponseStatus` and return error statuses on validation failures. See: `branch_hub/lib/branch_hub/server.ex`, `branch_hub/lib/internal_api/include/internal_api/response_status.pb.ex`
- Query layer uses `BranchesQueries` with Ecto and Scrivener pagination. See: `branch_hub/lib/branch_hub/model/branches_queries.ex`, `branch_hub/lib/branch_hub/repo.ex`
- Config layering: compile-time config in `config/config.exs` plus environment config files, runtime env in `config/runtime.exs`. See: `branch_hub/config/config.exs`, `branch_hub/config/runtime.exs`

# Dependency & Tooling Management
- Mix/Hex project with lockfile `mix.lock`. See: `branch_hub/mix.exs`, `branch_hub/mix.lock`
- Protobuf generation uses Dockerized `renderedtext/protoc` and `scripts/internal_protos.sh`. See: `branch_hub/Makefile`, `branch_hub/scripts/internal_protos.sh`
- Tooling configs: `.formatter.exs` and `.credo.exs`. See: `branch_hub/.formatter.exs`, `branch_hub/.credo.exs`

# Database / Storage
- Postgres configured via env vars (`POSTGRES_DB_*`) and `BranchHub.Repo`. See: `branch_hub/config/runtime.exs`, `branch_hub/lib/branch_hub/repo.ex`
- Local dev DB is Postgres 9.6.0 via docker-compose with a named volume `postgres-data`. See: `branch_hub/docker-compose.yml`
- Migrations live under `priv/repo/migrations/` and include Postgres extensions (`uuid-ossp`, `pg_trgm`, `btree_gin`). See: `branch_hub/priv/repo/migrations/20210906124818_add_branches_table.exs`, `branch_hub/priv/repo/migrations/20210909140659_add_indexes_to_branches_table.exs`
- Seeds/reset scripts: Unknown / verify (no seed/reset scripts under `branch_hub/priv/`). See: `branch_hub/priv/repo/migrations/20210906124818_add_branches_table.exs`

# Observability / Debugging
- Logging uses `Logger` with a custom console format and Sentry logger backend; log level comes from `LOG_LEVEL`. See: `branch_hub/config/config.exs`, `branch_hub/config/runtime.exs`
- Metrics use Watchman with host/port/prefix from env; gRPC handlers benchmark using `Util.Metrics`. See: `branch_hub/config/runtime.exs`, `branch_hub/lib/branch_hub/server.ex`
- gRPC health server is started alongside the main server. See: `branch_hub/lib/branch_hub/application.ex`

# Security / Compliance
- Secrets/config are provided via environment variables (DB credentials, Sentry DSN). See: `branch_hub/config/runtime.exs`
- CI security checks run `make check.ex.code`, `make check.ex.deps`, and `make check.docker`. See: `.semaphore/semaphore.yml`, `Makefile`
- Runtime container runs as a non-root user in the release image. See: `branch_hub/Dockerfile`

# PR Checklist
- [ ] Run `make format.ex`, `make lint.ex`, and `make test.ex`. See: `.semaphore/semaphore.yml`, `Makefile`
- [ ] If protobufs change, run `make pb.gen` to regenerate `lib/internal_api/*.pb.ex`. See: `branch_hub/Makefile`, `branch_hub/scripts/internal_protos.sh`
- [ ] If DB schema changes, add a migration under `priv/repo/migrations/` and ensure `mix ecto.create, ecto.migrate` passes. See: `branch_hub/priv/repo/migrations/20210906124818_add_branches_table.exs`, `branch_hub/Makefile`
- [ ] If runtime env vars or ports change, update `config/runtime.exs`, `docker-compose.yml`, and Helm values/templates. See: `branch_hub/config/runtime.exs`, `branch_hub/docker-compose.yml`, `branch_hub/helm/templates/deployment.yaml`
- [ ] Branching/release conventions: Unknown / verify (no BranchHub-specific guidance in `branch_hub/README.md` or `branch_hub/Makefile`).
