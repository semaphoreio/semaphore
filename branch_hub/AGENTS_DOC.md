# System Overview
- BranchHub is an Elixir application that manages branches and exposes gRPC APIs (describe, list, find_or_create, archive, filter). See: `branch_hub/README.md`, `branch_hub/lib/branch_hub/server.ex`
- Persistence uses Ecto/Postgres with a `branches` table and pagination via Scrivener. See: `branch_hub/lib/branch_hub/repo.ex`, `branch_hub/lib/branch_hub/model/branches.ex`, `branch_hub/priv/repo/migrations/20210906124818_add_branches_table.exs`
- Deployment artifacts include Docker (release build) and Helm charts for a gRPC service on port 50051. See: `branch_hub/Dockerfile`, `branch_hub/helm/templates/deployment.yaml`, `branch_hub/lib/branch_hub/application.ex`

# Architecture Diagram (Text)
```
[gRPC clients]
      |
      v
BranchHub gRPC Server (BranchHub.Server) --- Sentry.Grpc/Logger
      |
      v
BranchesQueries -> Repo (Ecto/Scrivener) -> Postgres (branches table)
      |
      v
Watchman metrics (via Util.Metrics)
```
- Evidence for components and links. See: `branch_hub/lib/branch_hub/application.ex`, `branch_hub/lib/branch_hub/server.ex`, `branch_hub/lib/branch_hub/model/branches_queries.ex`, `branch_hub/lib/branch_hub/repo.ex`, `branch_hub/config/runtime.exs`

# Components
## BranchHub gRPC Service
- Location (paths): `branch_hub/lib/branch_hub/application.ex`, `branch_hub/lib/branch_hub/server.ex`
- Responsibilities: implement gRPC API for branch operations (describe, list, find_or_create, archive, filter). See: `branch_hub/lib/branch_hub/server.ex`
- Entry points: `BranchHub.Application.start/2` starts `GRPC.Server.Supervisor` with `BranchHub.Server` and `GrpcHealthCheck.Server`; gRPC port is hard-coded to 50051. See: `branch_hub/lib/branch_hub/application.ex`
- Key modules: `BranchHub.Server`, `BranchHub.Application`. See: `branch_hub/lib/branch_hub/server.ex`, `branch_hub/lib/branch_hub/application.ex`
- Data stores used: Postgres via `BranchHub.Repo` (branches table). See: `branch_hub/lib/branch_hub/repo.ex`, `branch_hub/priv/repo/migrations/20210906124818_add_branches_table.exs`
- External dependencies: gRPC/protobuf (`InternalApi.Branch.*`), `Sentry.Grpc`, `Util.Metrics`, `UUID`. See: `branch_hub/lib/branch_hub/server.ex`, `branch_hub/lib/internal_api/branch.pb.ex`, `branch_hub/mix.exs`
- How it communicates: gRPC service `InternalApi.Branch.BranchService.Service` over port 50051; responses include `InternalApi.ResponseStatus`. See: `branch_hub/lib/branch_hub/server.ex`, `branch_hub/lib/internal_api/branch.pb.ex`
- Extension points: add new RPCs in `BranchHub.Server` and update/generated protobuf modules. See: `branch_hub/lib/branch_hub/server.ex`, `branch_hub/scripts/internal_protos.sh`, `branch_hub/Makefile`
- Gotchas:
  - gRPC port is hard-coded (`@grpc_port 50_051`), not driven by config/env. See: `branch_hub/lib/branch_hub/application.ex`
  - `filter/2` returns an empty response (no logic). See: `branch_hub/lib/branch_hub/server.ex`
  - `find_or_create` requires `repository_id` but the schema does not persist it (no field), so it is ignored by changeset. Unknown / verify expected behavior. See: `branch_hub/lib/branch_hub/server.ex`, `branch_hub/lib/branch_hub/model/branches.ex`, `branch_hub/priv/repo/migrations/20210906124818_add_branches_table.exs`

## Branches Persistence Layer
- Location (paths): `branch_hub/lib/branch_hub/repo.ex`, `branch_hub/lib/branch_hub/model/branches.ex`, `branch_hub/lib/branch_hub/model/branches_queries.ex`
- Responsibilities: validate branch data, perform inserts/upserts, list/filter with pagination, and archive branches. See: `branch_hub/lib/branch_hub/model/branches_queries.ex`, `branch_hub/lib/branch_hub/model/branches.ex`
- Entry points: `BranchesQueries.insert/1`, `get_or_insert/1`, `get_by_id/1`, `get_by_name/2`, `list/3`, `archive/2`. See: `branch_hub/lib/branch_hub/model/branches_queries.ex`
- Key modules: `BranchHub.Model.Branches` (schema/changeset), `BranchHub.Repo`. See: `branch_hub/lib/branch_hub/model/branches.ex`, `branch_hub/lib/branch_hub/repo.ex`
- Data stores used: Postgres `branches` table. See: `branch_hub/priv/repo/migrations/20210906124818_add_branches_table.exs`
- External dependencies: `Ecto`, `Scrivener`, `LogTee`, `Util.ToTuple`. See: `branch_hub/lib/branch_hub/model/branches_queries.ex`, `branch_hub/lib/branch_hub/repo.ex`, `branch_hub/mix.exs`
- How it communicates: `BranchHub.Repo` reads/writes to Postgres. See: `branch_hub/lib/branch_hub/repo.ex`, `branch_hub/config/runtime.exs`
- Extension points: add new filters in `BranchesQueries.list/3` and update indexes to support new query patterns. See: `branch_hub/lib/branch_hub/model/branches_queries.ex`, `branch_hub/priv/repo/migrations/20210909140659_add_indexes_to_branches_table.exs`
- Gotchas:
  - `get_or_insert/1` uses `on_conflict: {:replace_all_except, [:id, :inserted_at]}` and `conflict_target: [:project_id, :name]`, so upserts overwrite most fields and always clear `archived_at`. See: `branch_hub/lib/branch_hub/model/branches_queries.ex`
  - `list/3` relies on `ilike(display_name, "%name_contains%")` and uses GIN/trgm indexes defined in migrations. See: `branch_hub/lib/branch_hub/model/branches_queries.ex`, `branch_hub/priv/repo/migrations/20210909140659_add_indexes_to_branches_table.exs`

## Generated Internal API Protobufs
- Location (paths): `branch_hub/lib/internal_api/branch.pb.ex`, `branch_hub/lib/internal_api/include/internal_api/response_status.pb.ex`, `branch_hub/lib/internal_api/include/google/protobuf/timestamp.pb.ex`
- Responsibilities: define gRPC service/messages used by `BranchHub.Server`. See: `branch_hub/lib/internal_api/branch.pb.ex`
- Entry points: `InternalApi.Branch.BranchService.Service`, message modules like `InternalApi.Branch.Branch` and request/response structs. See: `branch_hub/lib/internal_api/branch.pb.ex`
- External dependencies: generated via protoc using `protoc-gen-elixir`. See: `branch_hub/scripts/internal_protos.sh`, `branch_hub/Makefile`
- Extension points: update proto definitions in the `internal_api` repo and regenerate with `make pb.gen`. See: `branch_hub/Makefile`, `branch_hub/scripts/internal_protos.sh`

# Data Model & Persistence
- Database: PostgreSQL configured via `BranchHub.Repo` and runtime env vars. See: `branch_hub/lib/branch_hub/repo.ex`, `branch_hub/config/runtime.exs`
- `branches` table fields include `id` (uuid), `name`, `display_name`, `project_id`, PR fields, `ref_type`, `archived_at`, `used_at`, timestamps with `created_at`. See: `branch_hub/priv/repo/migrations/20210906124818_add_branches_table.exs`
- Indexes: unique on `(project_id, name)` plus GIN/trgm indexes on `display_name` and combined project/display_name; additional indexes on `archived_at` and `used_at`. See: `branch_hub/priv/repo/migrations/20210909140659_add_indexes_to_branches_table.exs`
- Schema validation: `ref_type` must be one of `pull-request`, `tag`, or `branch`; required fields are `name`, `display_name`, `project_id`, `ref_type`. See: `branch_hub/lib/branch_hub/model/branches.ex`
- Relationships: no Ecto associations defined; `project_id` is a UUID field only. Unknown / verify if foreign keys exist elsewhere. See: `branch_hub/lib/branch_hub/model/branches.ex`

# Request / Job Flows
- Describe Branch: gRPC `describe` → param validation/UUID checks → `BranchesQueries.get_by_id/1` or `get_by_name/2` → serialize → `DescribeResponse`. See: `branch_hub/lib/branch_hub/server.ex`, `branch_hub/lib/branch_hub/model/branches_queries.ex`
- List Branches: gRPC `list` → parse filters/types → `BranchesQueries.list/3` → `Repo.paginate` → `ListResponse` with pagination metadata. See: `branch_hub/lib/branch_hub/server.ex`, `branch_hub/lib/branch_hub/model/branches_queries.ex`, `branch_hub/lib/branch_hub/repo.ex`
- Find or Create Branch: gRPC `find_or_create` → validate project/repository IDs → `BranchesQueries.get_or_insert/1` (upsert on `project_id` + `name`) → `FindOrCreateResponse`. See: `branch_hub/lib/branch_hub/server.ex`, `branch_hub/lib/branch_hub/model/branches_queries.ex`
- Archive Branch: gRPC `archive` → `BranchesQueries.archive/2` (sets `archived_at`) → `ArchiveResponse`. See: `branch_hub/lib/branch_hub/server.ex`, `branch_hub/lib/branch_hub/model/branches_queries.ex`

# Configuration & Environments
- Compile-time config: `config/config.exs` sets logger behavior, gRPC start, and repo config. See: `branch_hub/config/config.exs`
- Runtime config: `config/runtime.exs` reads env vars for DB, log level, metrics, and Sentry. See: `branch_hub/config/runtime.exs`
- Test config: `config/test.exs` enables SQL sandbox and JUnit formatter output. See: `branch_hub/config/test.exs`
- Environment variables used: `LOG_LEVEL`, `POSTGRES_DB_NAME`, `POSTGRES_DB_USER`, `POSTGRES_DB_PASSWORD`, `POSTGRES_DB_HOST`, `POSTGRES_DB_POOL_SIZE`, `POSTGRES_DB_SSL`, `METRICS_NAMESPACE`, `SENTRY_DSN`, `SENTRY_ENV`. See: `branch_hub/config/runtime.exs`
- gRPC port is not configurable via config/env (hard-coded). See: `branch_hub/lib/branch_hub/application.ex`

# Infrastructure & Deployment (as implemented here)
- Docker build: multi-stage Dockerfile builds a release and runs `bin/branch_hub start` as a non-root user. See: `branch_hub/Dockerfile`
- Local dev: `docker-compose.yml` runs the app with `mix run --no-halt` and a Postgres 9.6 container, exposing gRPC on 50051. See: `branch_hub/docker-compose.yml`
- Kubernetes/Helm: chart defines a gRPC Service and Deployment, DB env wiring, optional statsd sidecar, and gRPC probes. See: `branch_hub/helm/templates/deployment.yaml`, `branch_hub/helm/values.yaml`
- CI: BranchHub pipelines build images, run QA (format/lint/test), and perform security checks via `make check.*`. See: `.semaphore/semaphore.yml`, `Makefile`, `branch_hub/Makefile`

# Testing Strategy (as implemented here)
- ExUnit tests cover gRPC server logic and query behavior; tests live under `test/branch_hub/`. See: `branch_hub/test/branch_hub/server_test.exs`, `branch_hub/test/branch_hub/model/branches_queries_test.exs`
- SQL sandbox is used for DB tests (`RepoCase` and `test_helper.exs`). See: `branch_hub/test/support/repo_case.ex`, `branch_hub/test/test_helper.exs`
- Tests are run via `make test.ex` which uses `test.ex.setup` to create/migrate the DB. See: `Makefile`, `branch_hub/Makefile`

# Observability
- Logging: `Logger` console formatting and `Sentry.LoggerBackend` configured in config. See: `branch_hub/config/config.exs`
- Metrics: `Util.Metrics.benchmark/2` is used around gRPC handlers; Watchman config defines host/port/prefix. See: `branch_hub/lib/branch_hub/server.ex`, `branch_hub/config/runtime.exs`
- Error reporting: `Sentry.Grpc` is enabled for the gRPC service with env-driven Sentry config. See: `branch_hub/lib/branch_hub/server.ex`, `branch_hub/config/runtime.exs`
- Tracing: Unknown / verify (no tracing libraries or configs found). See: `branch_hub/mix.exs`

# “How to Extend” Playbooks
- Add a new gRPC endpoint:
  - Update the Branch service proto in the `internal_api` repo and regenerate Elixir stubs with `make pb.gen` (calls `scripts/internal_protos.sh`). See: `branch_hub/Makefile`, `branch_hub/scripts/internal_protos.sh`
  - Implement the RPC in `BranchHub.Server` and map request/response structs. See: `branch_hub/lib/branch_hub/server.ex`, `branch_hub/lib/internal_api/branch.pb.ex`
  - Add/extend tests in `test/branch_hub/server_test.exs`. See: `branch_hub/test/branch_hub/server_test.exs`
- Add a new DB table/migration:
  - Create a migration under `priv/repo/migrations/` and add a schema module under `lib/branch_hub/model/`. See: `branch_hub/priv/repo/migrations/20210906124818_add_branches_table.exs`, `branch_hub/lib/branch_hub/model/branches.ex`
  - Add query functions in `BranchesQueries` and use them from the gRPC server. See: `branch_hub/lib/branch_hub/model/branches_queries.ex`, `branch_hub/lib/branch_hub/server.ex`
- Add a new field to Branches:
  - Add the column in a migration and update the `Branches` schema/changeset; update serialization in `BranchHub.Server`. See: `branch_hub/lib/branch_hub/model/branches.ex`, `branch_hub/lib/branch_hub/server.ex`, `branch_hub/priv/repo/migrations/20210906124818_add_branches_table.exs`
  - If the field is used for filtering/search, consider adding indexes like the existing GIN/trgm examples. See: `branch_hub/priv/repo/migrations/20210909140659_add_indexes_to_branches_table.exs`
- Add a new config option:
  - Define it in `config/runtime.exs` (env-driven), then consume via `Application.get_env/2` or similar in code. Unknown / verify current access pattern because only Repo/Logger/Sentry/Watchman config is present. See: `branch_hub/config/runtime.exs`, `branch_hub/lib/branch_hub/application.ex`
  - If it affects runtime deployment, add the env var to `docker-compose.yml` and Helm values/templates. See: `branch_hub/docker-compose.yml`, `branch_hub/helm/templates/deployment.yaml`

# Appendix: Index of Important Files
- `branch_hub/README.md` — service description and capabilities.
- `branch_hub/lib/branch_hub/application.ex` — OTP supervision tree and gRPC startup.
- `branch_hub/lib/branch_hub/server.ex` — gRPC API implementation and request handling.
- `branch_hub/lib/branch_hub/model/branches.ex` — Ecto schema and changeset.
- `branch_hub/lib/branch_hub/model/branches_queries.ex` — DB query logic and filters.
- `branch_hub/lib/branch_hub/repo.ex` — Ecto repo configuration and pagination.
- `branch_hub/priv/repo/migrations/20210906124818_add_branches_table.exs` — base schema.
- `branch_hub/priv/repo/migrations/20210909140659_add_indexes_to_branches_table.exs` — indexes/extensions.
- `branch_hub/lib/internal_api/branch.pb.ex` — generated gRPC service/messages.
- `branch_hub/config/runtime.exs` — env-driven runtime configuration.
- `branch_hub/Dockerfile` — release build and runtime image.
- `branch_hub/docker-compose.yml` — local dev container stack.
- `branch_hub/helm/templates/deployment.yaml` — K8s service/deployment.
- `.semaphore/semaphore.yml` — CI pipeline for BranchHub.
- `branch_hub/Makefile` — service-specific build/test/proto generation.
