# Repository Architecture Notes

## Purpose & High-Level Flow
- This Mix project (`mix.exs`) hosts Semaphore’s periodic workflow scheduler. It exposes a gRPC API (`lib/scheduler/grpc_server.ex`, `lib/scheduler/health_check_server.ex`) that the control plane uses to CRUD periodic definitions and trigger runs.
- `Scheduler.Application` boots the critical OTP tree: both Postgres repos, the gRPC servers, Quantum-based cron scheduler, the dynamic schedule task supervisor, initializer, and the RabbitMQ consumers that react to org block/unblock events.
- At runtime, `Scheduler.Workers.QuantumScheduler` converts cron strings into Quantum jobs that call `Scheduler.Actions.start_schedule_task/2`. Each run spawns a `Scheduler.Workers.ScheduleTask` process to orchestrate workflow execution via downstream APIs.

## Directory Cheat Sheet
- `lib/scheduler/*` holds service code grouped by concern (actions, workers, clients, repos, DB models, utils).
- `lib/internal_api` mirrors protobuf/gRPC stubs pulled from `renderedtext/internal_api`. Run `make pb.gen` if proto inputs change.
- `priv/periodics_repo` and `priv/front_repo` store migrations for the two databases. `lib/scheduler/periodics` and `lib/scheduler/front_db` carry the matching schemas/query modules.
- `test/` mirrors `lib/` one-to-one; heavier integration helpers sit under `test/support`.
- Deploy tooling: `Dockerfile`, `docker-compose.yml`, `helm/`, `rel/`. Helper scripts live in `scripts/` (notably `internal_protos.sh` and `vagrant_sudo`).

## Runtime Components
- **Actions layer** (`lib/scheduler/actions*.ex`): thin service layer invoked by gRPC endpoints. Each action module (ApplyImpl, ListImpl, PersistImpl, etc.) encapsulates validation, DB access, and calls to external services. Metrics are emitted via Watchman (see counters in `Scheduler.Actions`).
- **Workers**: `Initializer` pre-warms Quantum jobs by paging through `Scheduler.Periodics.Model.PeriodicsQueries`. `QuantumScheduler` owns long-lived cron jobs, while `ScheduleTaskManager` supervises short-lived `ScheduleTask` processes that call downstream APIs (`WorkflowClient`, `ProjecthubClient`, `RepositoryClient`, `RepoProxyClient`).
- **Messaging**: `Scheduler.EventsConsumers.OrgBlocked` / `OrgUnblocked` subscribe to RabbitMQ via Tackle. They suspend/resume Quantum jobs in batches per organization.
- **Feature flags & metrics**: `FeatureProvider.init/1` picks either YAML-based flags (when `FEATURE_YAML_PATH` exists) or the gRPC-driven `Scheduler.FeatureHubProvider`. Observability is wired through `watchman` and `vmstats` (`Scheduler.VmstatsSink`, `config/config.exs`).

## Data & Persistence
- `Scheduler.PeriodicsRepo` targets the `periodics_*` database (cron definitions, triggers, delete requests). Key schemas live under `lib/scheduler/periodics/model/`.
- `Scheduler.FrontRepo` connects to the `front_*` DB for project/org metadata (`lib/scheduler/front_db/*`).
- Trigger history is modeled in `lib/scheduler/periodics_triggers/model`, offering both offset (`Scrivener`) and keyset (`Paginator`) pagination helpers.
- Soft-delete pipeline: requests are staged through `lib/scheduler/delete_requests/model` and eventually cleared by workers.
- Config lives in `config/*.exs` with prod overrides in `config/runtime.exs`; most secrets arrive via env vars (`DB_*`, `RABBITMQ_URL`, `INTERNAL_API_URL_*`).

## Build, Test, and Common Commands
- `mix deps.get && mix compile` – install deps and compile locally.
- `mix test` (optionally `--cover` or `--only integration`) – ExUnit suite; reports land in `./out/test-reports.xml` when `JunitFormatter` is enabled.
- `MIX_ENV=test make test.ex.setup` – boot Postgres (docker compose) and run migrations + seeds for integration specs.
- `mix credo --strict` and `mix format` – lint/format gates prior to commits.
- `docker compose up app` – run the scheduler plus backing services via the provided compose file; adjust `.env` as needed.
- `make pb.gen` – clone `renderedtext/internal_api`, regenerate protobuf stubs into `lib/internal_api`.

## External Dependencies & Touchpoints
- gRPC backends: feature API, repository hub, repo proxy, project hub, and workflow API. Their endpoints are injected via `INTERNAL_API_URL_*` variables (see `config/runtime.exs`).
- RabbitMQ exchange `organization_exchange` (routing keys `blocked` / `unblocked`) throttles scheduling when an org’s billing status changes.
- FeatureProvider cache uses Cachex (started in `Scheduler.Application` for non-Test environments) with 10-minute TTL.
- Metrics flow to Watchman/StatsD (namespaced by `METRICS_*` env vars); VM stats are emitted every 10s.

## Tips for Future Changes
- Touching cron semantics? Update both Quantum job creation (`QuantumScheduler`) and the validation logic inside `Scheduler.Actions.ApplyImpl` / `PersistImpl`.
- When adjusting DB queries, remember both pagination strategies (`paginate_offset` and `paginate_keyset`) and the mirrored tests in `test/periodics_*`.
- New gRPC fields require regenerating protos (`make pb.gen`) and updating the transformation helpers in `Scheduler.Grpc.Server`.
- Long-running tasks should go through `ScheduleTaskManager` to benefit from supervision and Watchman metrics; avoid blocking the Quantum scheduler process.
