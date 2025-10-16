# Plumber Stack Documentation Hub

This document stitches together the service-level docs under `doc/` so you have a single place to understand how the plumber stack fits together. Follow the links for deep dives.

## System Overview
- **Pipelines (`ppl/`)** – primary gRPC surface and orchestrator for pipeline/workflow state machines. It persists pipeline data, publishes AMQP events, and coordinates subordinate apps ([doc/ppl/DOCUMENTATION.md](doc/ppl/DOCUMENTATION.md)).
- **Block (`block/`)** – manages block lifecycle and Zebra task orchestration, reacting to RabbitMQ events to advance block/task state ([doc/block/DOCUMENTATION.md](doc/block/DOCUMENTATION.md)).
- **Definition Validator** – validates pipeline YAML (schema + semantic rules) before anything is persisted ([doc/definition_validator/DOCUMENTATION.md](doc/definition_validator/DOCUMENTATION.md)).
- **Job Matrix** – expands `matrix` / `parallelism` definitions into concrete job variants for downstream schedulers ([doc/job_matrix/DOCUMENTATION.md](doc/job_matrix/DOCUMENTATION.md)).
- **Gofer Client** – gRPC client for promotion workflows; wraps request formatting, transport, and response parsing ([doc/gofer_client/DOCUMENTATION.md](doc/gofer_client/DOCUMENTATION.md)).
- **Looper** – shared macros/utilities that generate STM and periodic workers used by `ppl` and `block` ([doc/looper/DOCUMENTATION.md](doc/looper/DOCUMENTATION.md)).
- **Referents** – `repo_proxy_ref` (repo metadata) and `task_api_referent` (Zebra stand-in) supply deterministic fixtures for tests/local runs ([doc/repo_proxy_ref/DOCUMENTATION.md](doc/repo_proxy_ref/DOCUMENTATION.md), [doc/task_api_referent/DOCUMENTATION.md](doc/task_api_referent/DOCUMENTATION.md)).

## Core Pipeline Lifecycle
1. **Ingress** – gRPC handlers in `ppl` accept schedule/terminate/list calls, convert protobufs into domain commands, and run YAML through `definition_validator` ([doc/ppl/DOCUMENTATION.md](doc/ppl/DOCUMENTATION.md), [doc/definition_validator/DOCUMENTATION.md](doc/definition_validator/DOCUMENTATION.md)).
2. **Job Expansion** – `job_matrix` (and `parallelism` helpers) expand job definitions before pipeline/block rows are inserted ([doc/job_matrix/DOCUMENTATION.md](doc/job_matrix/DOCUMENTATION.md)).
3. **State Persistence** – `ppl` writes pipeline/build metadata via `Ppl.EctoRepo` and triggers Looper STM workers (`Ppl.Sup.STM`) ([doc/ppl/DOCUMENTATION.md](doc/ppl/DOCUMENTATION.md), [doc/looper/DOCUMENTATION.md](doc/looper/DOCUMENTATION.md)).
4. **Block Execution** – STM workers in `block` create and monitor Zebra tasks, consuming RabbitMQ events (`task_state_exchange`) to move blocks forward ([doc/block/DOCUMENTATION.md](doc/block/DOCUMENTATION.md)).
5. **Completion & Notifications** – `ppl` publishers emit pipeline/block/after-pipeline events over RabbitMQ for UI subscribers, and `gofer_client` notifies Gofer when promotions are involved ([doc/ppl/DOCUMENTATION.md](doc/ppl/DOCUMENTATION.md), [doc/gofer_client/DOCUMENTATION.md](doc/gofer_client/DOCUMENTATION.md)).
6. **Testing & Referents** – During local/integration runs, referent services respond to repo/task RPCs so flows complete without external dependencies ([doc/repo_proxy_ref/DOCUMENTATION.md](doc/repo_proxy_ref/DOCUMENTATION.md), [doc/task_api_referent/DOCUMENTATION.md](doc/task_api_referent/DOCUMENTATION.md)).

## Data Stores & Messaging
- **PostgreSQL** – `Ppl.EctoRepo` and `Block.EctoRepo` house pipeline/block/task state; migrations live alongside each app ([doc/ppl/DOCUMENTATION.md](doc/ppl/DOCUMENTATION.md), [doc/block/DOCUMENTATION.md](doc/block/DOCUMENTATION.md)).
- **RabbitMQ** – primary event bus (`pipeline_state_exchange`, `pipeline_block_state_exchange`, `after_pipeline_state_exchange`, `task_state_exchange`) for cross-service coordination ([doc/ppl/DOCUMENTATION.md](doc/ppl/DOCUMENTATION.md), [doc/block/DOCUMENTATION.md](doc/block/DOCUMENTATION.md)).
- **Watchman / LogTee** – metrics and structured logging used by STM workers and gRPC surfaces for observability ([doc/ppl/DOCUMENTATION.md](doc/ppl/DOCUMENTATION.md), [doc/block/DOCUMENTATION.md](doc/block/DOCUMENTATION.md), [doc/looper/DOCUMENTATION.md](doc/looper/DOCUMENTATION.md)).

## External Integrations
- **Zebra Task API** – accessed via internal clients; mimic behaviour with `task_api_referent` in non-prod environments ([doc/block/DOCUMENTATION.md](doc/block/DOCUMENTATION.md), [doc/task_api_referent/DOCUMENTATION.md](doc/task_api_referent/DOCUMENTATION.md)).
- **Repo Proxy** – pipeline scheduling pulls repo metadata from repo-proxy (or the referent stub) before reading YAML ([doc/repo_proxy_ref/DOCUMENTATION.md](doc/repo_proxy_ref/DOCUMENTATION.md)).
- **Gofer** – promotions go through Gofer via `gofer_client`; guard with `SKIP_PROMOTIONS` for dev/test ([doc/gofer_client/DOCUMENTATION.md](doc/gofer_client/DOCUMENTATION.md)).

## Local Development & Operations
- Run `mix setup` inside `ppl/`, `block/`, `definition_validator/`, `job_matrix/`, `gofer_client/`, and `looper/` to install deps and prepare databases ([doc/ppl/AGENTS.md](doc/ppl/AGENTS.md), [doc/block/AGENTS.md](doc/block/AGENTS.md)).
- Launch the stack by starting `repo_proxy_ref` and `task_api_referent` (if external services unavailable), then `ppl` via `iex -S mix` ([doc/repo_proxy_ref/AGENTS.md](doc/repo_proxy_ref/AGENTS.md), [doc/task_api_referent/DOCUMENTATION.md](doc/task_api_referent/DOCUMENTATION.md), [doc/ppl/AGENTS.md](doc/ppl/AGENTS.md)).
- Migrations often affect both repos; use `mix ecto.migrate -r Ppl.EctoRepo -r Block.EctoRepo` to keep schemas in sync ([doc/ppl/AGENTS.md](doc/ppl/AGENTS.md)).
- Looper-based workers leverage `cooling_time_sec` and Wormhole retries; adjust configs or inspect metrics when loops stall ([doc/looper/DOCUMENTATION.md](doc/looper/DOCUMENTATION.md)).

## Testing & QA
- Each app has its own `mix test` suite; run the failing service’s tests first (e.g. `cd block && MIX_ENV=test mix test`) ([doc/block/AGENTS.md](doc/block/AGENTS.md)).
- `definition_validator` includes fixture-based tests (`mix test.watch` is handy while editing schemas) ([doc/definition_validator/DOCUMENTATION.md](doc/definition_validator/DOCUMENTATION.md)).
- Library apps (`job_matrix`, `gofer_client`, `looper`) are pure and quick to test—use them to pin down regressions before integrating ([doc/job_matrix/DOCUMENTATION.md](doc/job_matrix/DOCUMENTATION.md), [doc/gofer_client/DOCUMENTATION.md](doc/gofer_client/DOCUMENTATION.md), [doc/looper/DOCUMENTATION.md](doc/looper/DOCUMENTATION.md)).
- Referents have their own suites to lock in canned scenarios; update tests when extending mock behaviours ([doc/repo_proxy_ref/DOCUMENTATION.md](doc/repo_proxy_ref/DOCUMENTATION.md), [doc/task_api_referent/DOCUMENTATION.md](doc/task_api_referent/DOCUMENTATION.md)).

## Observability Checklist
- Metrics prefixes: `Ppl.*`, `Block.*`, `Looper.*` (Watchman).
- Log correlation keys: `ppl_id`, `wf_id`, `block_id`, `task_id`, `request_token` (LogTee).
- RabbitMQ DLQs hint at decode/state issues—investigate when STM workers stall.
- gRPC health endpoints exposed via each service’s `HealthCheck` module support Kubernetes probes ([doc/ppl/DOCUMENTATION.md](doc/ppl/DOCUMENTATION.md), [doc/block/DOCUMENTATION.md](doc/block/DOCUMENTATION.md), [doc/repo_proxy_ref/DOCUMENTATION.md](doc/repo_proxy_ref/DOCUMENTATION.md)).

## Reference Links
- Pipelines edge & workflows: [doc/ppl/DOCUMENTATION.md](doc/ppl/DOCUMENTATION.md), [doc/ppl/AGENTS.md](doc/ppl/AGENTS.md)
- Block lifecycle: [doc/block/DOCUMENTATION.md](doc/block/DOCUMENTATION.md), [doc/block/AGENTS.md](doc/block/AGENTS.md)
- YAML validation: [doc/definition_validator/DOCUMENTATION.md](doc/definition_validator/DOCUMENTATION.md), [doc/definition_validator/AGENTS.md](doc/definition_validator/AGENTS.md)
- Matrix expansion: [doc/job_matrix/DOCUMENTATION.md](doc/job_matrix/DOCUMENTATION.md), [doc/job_matrix/AGENTS.md](doc/job_matrix/AGENTS.md)
- Promotions: [doc/gofer_client/DOCUMENTATION.md](doc/gofer_client/DOCUMENTATION.md), [doc/gofer_client/AGENTS.md](doc/gofer_client/AGENTS.md)
- Worker macros: [doc/looper/DOCUMENTATION.md](doc/looper/DOCUMENTATION.md), [doc/looper/AGENTS.md](doc/looper/AGENTS.md)
- Referents: [doc/repo_proxy_ref/DOCUMENTATION.md](doc/repo_proxy_ref/DOCUMENTATION.md), [doc/task_api_referent/DOCUMENTATION.md](doc/task_api_referent/DOCUMENTATION.md)
