# AGENTS.md

## Overview
- Notifications service for Semaphore 2.0 projects (see `README.md`).
- Provides gRPC APIs and worker modules (Slack/email/webhook) that process events via RabbitMQ and persist rules in a database (see `docs/arch.md`, `lib/notifications/application.ex`, `lib/notifications/workers/`).
- Source-of-truth docs: `docs/specs.md` (requirements/use cases) and `docs/arch.md` (architecture reference).
- Branching/release conventions: Unknown / verify (no guidance in `README.md` or `docs/*`).

## Supported platforms / runtime versions
- Elixir ~> 1.12 (see `mix.exs`).
- Docker defaults: Elixir 1.12.3, OTP 24.3.4.17, Alpine 3.20.3 (see `Dockerfile`).
- Local dependencies via docker compose: Postgres 9.6 and RabbitMQ 3-management (see `docker-compose.yml`).

## Golden Rules (Must Follow)
- Run the formatter via `make format.ex` (uses `mix format` with `.formatter.exs` inputs) before pushing changes (see `../Makefile`, `.formatter.exs`).
- Keep lint clean with `make lint.ex` (Credo strict config) (see `../Makefile`, `.credo.exs`).
- Run tests with `make test.ex` so DB/Rabbit are set up and warnings are treated as errors (see `Makefile`, `../Makefile`).
- Do not hardcode secrets; use env or Secrethub as the code expects (see `config/runtime.exs`, `lib/notifications/workers/webhook/secret.ex`).
- If protobuf definitions change, regenerate stubs with `make pb.gen` (see `Makefile`, `scripts/internal_protos.sh`, `scripts/public_protos.sh`).
- When triaging problems, consult the architecture map in `AGENTS_DOC.md` to locate the right components quickly (see `AGENTS_DOC.md`).
- After resolving a task, update both `AGENTS.md` and `AGENTS_DOC.md` with new durable knowledge and links (see `AGENTS.md`, `AGENTS_DOC.md`).
- When a fix reveals new details or corrections, update the relevant sections in `AGENTS.md` and `AGENTS_DOC.md` so the docs reflect the current behavior (see `AGENTS.md`, `AGENTS_DOC.md`).

## Repo Map (High Level)
- `lib/` - OTP app, gRPC APIs, models, and workers (see `lib/notifications/application.ex`, `lib/notifications/api/public_api.ex`, `lib/notifications/workers/coordinator.ex`).
- `config/` - environment and runtime configuration (see `config/config.exs`, `config/runtime.exs`).
- `priv/repo/migrations/` - Ecto migrations used by releases and local setup (see `priv/repo/migrations`, `lib/notifications/migration.ex`).
- `test/` - ExUnit tests and support code (see `test/`, `config/test.exs`).
- `docs/` - specs and architecture references (see `docs/specs.md`, `docs/arch.md`).
- `helm/` - Helm chart and templates (see `helm/Chart.yaml`, `helm/values.yaml`).
- `scripts/` - protobuf generation helpers (see `scripts/internal_protos.sh`, `scripts/public_protos.sh`).
- `_build/`, `deps/` - build artifacts created by Mix and mounted by docker compose (see `docker-compose.yml`, `../Makefile`).
- Main entrypoints: `lib/notifications/application.ex` (OTP app), `lib/notifications/api/public_api.ex` and `lib/notifications/api/internal_api.ex` (gRPC services), `lib/notifications/workers/coordinator.ex` (RabbitMQ consumer).

## Build, Run, Test
- Prereqs: Docker and docker compose are required; build/test flows use containers (see `Dockerfile`, `docker-compose.yml`, `../Makefile`).
- Build image: `make build` (see `../Makefile`, `Dockerfile`).
- Run locally:
  - `make console.ex` (IEx) or `make console.bash`/`make console.sh` (shells) in docker compose (see `../Makefile`, `docker-compose.yml`).
  - Default `MIX_ENV` is `dev` unless overridden (see `Makefile`).
- Tests: `make test.ex` (runs `mix do ecto.create, ecto.migrate` via `test.ex.setup`, then `mix test --warnings-as-errors`) (see `Makefile`, `../Makefile`).
- Fast path: `make test.ex FILE=path/to/test.exs FLAGS=...` for targeted tests (see `../Makefile`).
- Protobuf generation: `make pb.gen` (clones internal/public API repos over SSH and runs `protoc` via scripts) (see `Makefile`, `scripts/internal_protos.sh`, `scripts/public_protos.sh`).
- CI behavior: when `CI` is set, `make test.ex.setup` starts Postgres and RabbitMQ via `sem-service`, then tests run in `docker run`; formatter runs in check-only mode (see `Makefile`, `../Makefile`). CI pipeline files are Unknown / verify (no `.github/workflows` or `.semaphore` under `notifications/`).

## Coding Conventions
- Ecto schemas use binary UUID primary keys and changesets for validation (see `lib/notifications/models/rule.ex`, `lib/notifications/models/notification.ex`, `lib/notifications/models/pattern.ex`).
- Repo lookup helpers return `{:ok, _}` / `{:error, :not_found}` tuples; prefer that pattern when adding queries (see `lib/notifications/models/rule.ex`).
- gRPC APIs are implemented with `GRPC.Server` and instrumented with `Sentry.Grpc`; public API extracts org/user IDs from headers (see `lib/notifications/api/public_api.ex`, `lib/notifications/api/internal_api.ex`).
- RabbitMQ consumers use `Tackle.Consumer` and decode protobuf events; processing is wrapped with `Watchman.benchmark` (see `lib/notifications/workers/coordinator.ex`).
- Logging uses `Logger` with request IDs; logger metadata includes `:module` and `:job_id` (see `lib/notifications/workers/webhook.ex`, `lib/notifications/workers/coordinator.ex`, `config/config.exs`).
- HTTP calls (Slack/Webhook) use HTTPoison with timeouts/retries and Watchman counters (see `lib/notifications/workers/slack.ex`, `lib/notifications/workers/webhook.ex`).

## Dependency & Tooling Management
- Dependencies are managed with Mix/Hex (`mix.exs`) and locked in `mix.lock`.
- Formatting and linting are configured by `.formatter.exs` and `.credo.exs` (see those files).
- Protobuf stubs live in `lib/internal_api` and `lib/public_api` and are generated via `make pb.gen` (see `scripts/internal_protos.sh`, `scripts/public_protos.sh`, `Makefile`).
- Docker build uses `mix deps.get`, `mix deps.compile`, and `mix release`; Sentry recompilation is baked in (see `Dockerfile`, `mix.exs`).
- Version manager: Unknown / verify (no `.tool-versions` or similar files under `notifications/`; only `mix.exs` and `Dockerfile` specify versions).

## Database / Storage
- Postgres via `Notifications.Repo` (Ecto) with config from env vars (see `lib/notifications/repo.ex`, `config/runtime.exs`).
- Migrations live in `priv/repo/migrations` and are run by `Notifications.Release.create_and_migrate` (see `priv/repo/migrations`, `lib/notifications/migration.ex`).
- Local dev DB is provided by docker compose `db` service with default credentials (see `docker-compose.yml`, `config/runtime.exs`).
- Seeds/reset procedures: Unknown / verify (no seed or reset tasks in `lib/notifications/migration.ex` or `Makefile`).

## Observability / Debugging
- Logger format and metadata are set in `config/config.exs`; log level is controlled by `LOG_LEVEL` (see `config/config.exs`, `config/runtime.exs`).
- Metrics use Watchman/StatsD with a `notifications.<namespace>` prefix (see `config/runtime.exs`, `lib/notifications/workers/coordinator.ex`, `lib/notifications/workers/webhook.ex`, `lib/notifications/workers/slack.ex`).
- Sentry is configured via `SENTRY_DSN`/`SENTRY_ENV` and enabled in non-dev/test (see `config/runtime.exs`, `lib/notifications/application.ex`).
- Local debugging shells via `make console.ex` or `make console.bash` (see `../Makefile`, `docker-compose.yml`).
- AMQP/lager logging is silenced to reduce noise (see `config/_silent_lager.exs`).

## Security / Compliance
- Secrets and service endpoints are supplied via env vars (e.g., `INTERNAL_API_URL_*`, `POSTGRES_DB_*`, `AMQP_URL`, `SENTRY_DSN`) (see `config/runtime.exs`).
- Webhook signing pulls the `WEBHOOK_SECRET` env var from Secrethub (see `lib/notifications/workers/webhook/secret.ex`).
- Authorization is enforced via RBAC gRPC permissions (`organization.notifications.*`, `project.view`) (see `lib/notifications/auth.ex`).
- Safe defaults for dev/test (DB creds, domain) are defined in runtime config and compose (see `config/runtime.exs`, `docker-compose.yml`).

## PR Checklist
- Run `make format.ex` (formatter) and ensure no diffs (see `../Makefile`, `.formatter.exs`).
- Run `make lint.ex` (Credo) and resolve findings (see `../Makefile`, `.credo.exs`).
- Run `make test.ex` (migrations + tests with warnings as errors) (see `Makefile`, `../Makefile`).
- If protobufs change, run `make pb.gen` and commit updates in `lib/internal_api`/`lib/public_api` (see `Makefile`, `scripts/internal_protos.sh`, `scripts/public_protos.sh`).
- If schema changes, add a migration in `priv/repo/migrations` and keep release migrations working (see `priv/repo/migrations`, `lib/notifications/migration.ex`).
