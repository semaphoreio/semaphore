# Architecture Handbook

## Overview
Zebra is an Elixir OTP application responsible for job lifecycle orchestration inside Semaphore. It exposes several gRPC services on port `50051`, coordinates queueing and dispatching through background workers, and delegates persistence to a legacy Postgres schema via Ecto.

## Code Layout
- `lib/zebra/application.ex` boots the supervision tree, wiring caches, the feature flag provider, and optional gRPC servers (public/internal job & task APIs, health checks). Services are toggled with `START_*` env vars.
- `lib/zebra/apis/` implements gRPC endpoints. Concrete service modules live under `public_job_api/`, `internal_job_api/`, and `internal_task_api/`, with shared helpers in `utils.ex`.
- `lib/protos/` houses protobuf contracts. Regenerate stubs with `mix grpc.gen` if schemas change upstream.
- `lib/zebra/models/` defines Ecto schemas and state helpers (`Job`, `Task`, `Project`, etc.). Database access goes through `Zebra.LegacyRepo`, whose migrations live in `priv/legacy_repo/migrations/`.
- `lib/zebra/workers/` contains GenServer pipelines (`Dispatcher`, `Scheduler`, `TaskFinisher`, callback handlers) driven by `Workers.active/1`. Workers rely on `DbWorker` to poll the legacy database and on Watchman metrics for observability.
- Support modules include `cache.ex` (Cachex caches), `monitor.ex` (Watchman instrumentation), `machines/` (brownout scheduling), and `feature_hub_provider.ex`.

## Data & External Dependencies
Endpoints for upstream services (artifacthub, cachehub, projecthub, RBAC, etc.) are configured in `config/*.exs` and default to `localhost:50051` for tests. Workers interact with AMQP (`tackle`), GRPC agents (`HostedAgent`, `SelfHostedAgent`), and feature flags (`FeatureProvider`). Secrets stay out of the repo—load them via `.env` for docker-compose.

## Running & Development
- `mix deps.get` to install dependencies; `make build` creates Docker images matching CI.
- `make dev.server` starts the Phoenix UI shelling into this service; alternatively `iex -S mix phx.server` if you need an interactive node.
- Feature flags require `FEATURE_YAML_PATH` or remote provider credentials before boot.

## Testing & Quality
- `make test.ex` wraps `mix test`, seeding/migrating the legacy repo automatically. Use `TEST_FILE=test/zebra/...` to scope cases.
- Workers and gRPC services have fake counterparts under `test/support/fake_servers/` to keep suites hermetic. Extend these fakes when adding new integrations.
- Linting/formatting: `make format.ex` (mix format + Credo), `make lint` for Go stubs (if any), and `make lint.js` for the Phoenix assets.

## Operations & Troubleshooting
- Set `WATCHMAN_HOST` to push metrics; logs are structured via Logger with Sentry backend (`Sentry.LoggerBackend`).
- Scheduler cadence and worker batch sizes live in `config/*.exs` (`Zebra.Workers.Scheduler`, `Dispatcher` timeouts). Tune via env overrides before scaling changes.
- For local brownout testing, edit `lib/zebra/machines/brownout_schedule.ex` and restart the node; the scheduler pulls updates on boot.
