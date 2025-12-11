# Block Service

## Overview
Block manages the execution lifecycle of pipeline blocks and their Zebra tasks. It persists block state, reacts to events emitted by the build system, coordinates stop/cancel transitions and publishes follow-up events through AMQP. Although it can run standalone, it is usually started under the main `ppl` application.

## Responsibilities
- Accept block execution requests produced by `ppl` and materialise them as `block_requests` and `block_builds` rows.
- Drive block state machines (`INITIALIZING`, `WAITING`, `RUNNING`, `STOPPING`, `DONE`) using Looper-based orchestrators under `Block.Sup.STM`.
- Monitor Zebra task lifecycle via `Block.Tasks.TaskEventsConsumer` (RabbitMQ exchange `task_state_exchange`, routing key `finished`) and advance corresponding block/task records.
- Coordinate compilation/after-pipeline callbacks through configurable hooks (`:compile_task_done_notification_callback` and `:after_ppl_task_done_notification_callback`).

## Architecture
- **Supervision tree**: `Block.Application` boots `Block.EctoRepo`, the STM supervisor (`Block.Sup.STM`) and the RabbitMQ consumer.
- **State machines**: Implemented in `block/lib/block/blocks/stm_handler/*` and `block/lib/block/tasks/stm_handler/*`; each handler is a Looper worker that periodically picks pending records.
- **Persistence**: `block/priv/ecto_repo/migrations` define tables for requests, builds, sub-pipelines, and task metadata. `Block.Repo` wraps PostgreSQL via `ecto_sql`.
- **External dependencies**: communicates with Zebra/Gofer through task IDs, validates commands with `definition_validator`, and emits notifications via AMQP and Watchman metrics.

## Data Flow Highlights
1. `ppl` schedules a block → `block_requests` + `block_builds` rows are created.
2. STM loopers transition blocks from `waiting` to `running`, provisioning tasks via Zebra.
3. Zebra marks task finished → RabbitMQ message consumed → STM handlers move block/task to `done`, determine result/reason and trigger callbacks.
4. Termination requests push blocks into `stopping` which instructs Zebra to cancel outstanding tasks; completion reason is persisted before publish.

## Configuration
- `RABBITMQ_URL` – connection string used by `Block.Tasks.TaskEventsConsumer` and Looper AMQP publishers.
- `COMPILE_TASK_DONE_NOTIFICATION_CALLBACK`, `AFTER_PPL_TASK_DONE_NOTIFICATION_CALLBACK` – optional MFA tuples configured in `config/*.exs` for cross-service signalling.
- Database credentials configured in `config/{dev,test,prod}.exs` under `Block.EctoRepo`.

## Operations
- Install deps & run migrations: `cd block && mix setup`.
- Start locally: `cd block && iex -S mix` (ensure Postgres & RabbitMQ are reachable).
- Run tests: `cd block && MIX_ENV=test mix test` (DB is managed by `mix test` fixtures).
- Lint: `cd block && mix credo`.

## Observability
- Metrics: most STM operations wrap `Util.Metrics.benchmark` (look for Watchman entries prefixed with `Block.*`).
- Logging: LogTee provides structured logs; search by `block_id`/`task_id` for correlation.
- RabbitMQ dead-letter queues should be monitored when state transitions stall (stuck messages indicate decoding issues).
