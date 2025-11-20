# Pipelines Service (ppl)

## Overview
`ppl` is the entry-point application of the plumber stack. It exposes the gRPC APIs defined in `InternalApi.Plumber.*` and `InternalApi.PlumberWF.*`, persists pipeline/workflow state, and coordinates subordinate services such as Block, Definition Validator, Gofer Client, and Job Matrix. The service accepts scheduling requests, drives pipeline state machines, emits AMQP events, and services listing/describe calls used by UI and automation clients.

## Responsibilities
- Handle gRPC traffic for pipeline (`PipelineService`, `Admin`) and workflow (`WorkflowService`) APIs via handlers under `ppl/lib/ppl/grpc/`.
- Persist pipelines, workflows, block/job snapshots, and auxiliary data in PostgreSQL (`Ppl.EctoRepo`).
- Orchestrate pipeline state transitions through STM workers started under `Ppl.Sup.STM` (Looper-driven).
- Publish pipeline/block/after-pipeline events to RabbitMQ exchanges for downstream consumers.
- Integrate with sibling services: Block for block execution, Definition Validator for YAML checks, Gofer for promotions, Zebra/Task API through clients.

## Architecture
- **Supervision tree**: `Ppl.Application` boots cache processes (`Ppl.Cache`), Ecto repo, Looper supervisors (`Ppl.Sup.STM`), RabbitMQ consumers (e.g. `Ppl.OrgEventsConsumer`), and the gRPC server (`GRPC.Server.Supervisor` with `Ppl.Grpc.Server`, `Plumber.WorkflowAPI.Server`, `Ppl.Admin.Server`, `Ppl.Grpc.HealthCheck`).
- **State machines**: Located in `ppl/lib/ppl/ppls/stm_handler/` (pipeline-level handlers) and other contexts; they poll for rows needing transitions (scheduling, stopping, cleanup).
- **GRPC layer**: Request/response modules under `ppl/lib/ppl/grpc/` translate protobuf messages to domain commands. Separate modules exist per surface (pipeline, workflow, admin, health).
- **Persistence**: Migrations live in `ppl/priv/repo/migrations`. Tables mirror proto structures (pipelines with state/result fields, workflows, queues, requesters, artefacts, etc.).
- **Caching**: `Ppl.Cache` (Cachex) stores frequently accessed data such as YAML payloads or queue lookups.
- **AMQP publishing**: See `ppl/lib/ppl/publishers/` for event emitters targeting `pipeline_state_exchange`, `pipeline_block_state_exchange`, and `after_pipeline_state_exchange`.

## External Interfaces
- **gRPC APIs**: Implements the surfaces defined in `proto/plumber.pipeline.proto` and `proto/plumber_w_f.workflow.proto` (schedule, describe, list, terminate, partial rebuild, run now, delete, admin terminate all, get yaml, etc.).
- **RabbitMQ**: Consumes organisation events (`Ppl.OrgEventsConsumer`) and publishes pipeline/block state events.
- **AMQP tasks**: Collaborates with Block which handles actual block execution; Ppl updates Block via database and AMQP triggers.
- **Gofer**: Uses `GoferClient` to create switches and notify promotions.
- **Task API**: Interacts with Zebra via Task API clients under `ppl/lib/ppl/task_api_client/` when managing tasks directly.

## Typical Flow
1. **Schedule**: `WorkflowService.Schedule` or `PipelineService.Schedule` receives a request → YAML validated (`DefinitionValidator`) → records created in Postgres → initial pipeline enters STM queue.
2. **Execution**: STM handler transitions pipeline to `pending`, `queuing`, `running`, and coordinates with Block to run blocks. Events published on each change.
3. **Inspection**: Clients call `Describe`/`DescribeMany`/`List*` handlers which query Ecto using modules in `ppl/lib/ppl/pipeline/query/` and `ppl/lib/ppl/workflow/workflow_queries.ex`.
4. **Termination**: `Terminate` or `TerminateAll` sets termination intent and pushes pipeline to `stopping`; Block handles per-block cancellation; final `DONE` event emitted.
5. **Promotions / Partial rebuild**: `ScheduleExtension` and `PartialRebuild` endpoints reuse existing pipeline metadata, call Gofer when needed, and ensure idempotency via request tokens.

## Configuration
Key environment variables (see `config/runtime.exs`):
- Database: `DATABASE_URL` (or specific `PPL_DATABASE_*` vars), pool size, SSL settings.
- AMQP: `RABBITMQ_URL` for publishers and consumers.
- Rate limiting: `IN_FLIGHT_DESCRIBE_LIMIT`, `IN_FLIGHT_LIST_LIMIT` used by `Ppl.Grpc.InFlightCounter`.
- Promotions: `SKIP_PROMOTIONS`, Gofer host/port.
- Telemetry/logging: Watchman, LogTee configuration, Sentry (if enabled).

## Operations
- Setup everything: `cd ppl && mix setup` (deps + migrations for both `Ppl.EctoRepo` and `Block.EctoRepo`).
- Run migrations: `mix ecto.migrate -r Ppl.EctoRepo -r Block.EctoRepo`.
- Tests: `mix test` (spawns gRPC mocks, uses sandbox DB).
- Lint: `mix credo`; Dialyzer: `mix dialyzer`.
- Start locally: `iex -S mix` (ensures gRPC server listens on configured port, default 50051).

## Observability
- Metrics: Watchman metrics emitted via `Util.Metrics` wrappers (search prefixes `Ppl.*`).
- Logging: LogTee structures logs with tags (`ppl_id`, `wf_id`, `request_token`).
- Events: RabbitMQ exchanges provide realtime state transitions; monitor for missing events when UI seems stale.
- Health: `Ppl.Grpc.HealthCheck` implements gRPC health checking (used by k8s).

## Key Code Hotspots
- Pipeline queries: `ppl/lib/ppl/workflow/workflow_queries.ex`, `ppl/lib/ppl/pipeline/query/`.
- STM handlers: `ppl/lib/ppl/ppls/stm_handler/*`.
- GRPC servers: `ppl/lib/ppl/grpc/server.ex`, `plumber/workflow_api/server.ex`, `ppl/admin/server.ex`.
- Idempotency: `ppl/lib/ppl/idempotency` modules ensure `request_token` semantics.
- Publishers: `ppl/lib/ppl/publishers/pipeline_event_publisher.ex` and related files.

Keep this document in sync with proto changes and major STM refactors.
