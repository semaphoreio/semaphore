# Plumber Agent Notes

This file is a fast lane when you need to patch or extend the Pipelines (plumber) service.

## Mental Model
- `ppl/` holds the gRPC boundary and state machines; handlers live under `ppl/lib/ppl/grpc/` and call into context modules under `ppl/lib/ppl/`.
- YAML validation, block execution, matrix expansion and Gofer integration are separate OTP apps within the repo (see `definition_validator/`, `block/`, `job_matrix/`, `gofer_client/`). They are started as dependencies of `ppl` via `mix.exs` and supervised from `Ppl.Application`.
- Protobufs live in `proto/` (`InternalApi.Plumber.*` and `InternalApi.PlumberWF.*`). When protos change run `mix deps.get` + `mix compile` inside `proto/` and `ppl/` to regenerate modules.
- Persistent data: PostgreSQL via `Ppl.EctoRepo` and `Block.EctoRepo`; migrations live under respective `priv/repo/migrations/` directories.

## Workflow Cheat Sheet
- **Local setup**: `cd ppl && mix setup` (installs deps, creates DBs, runs migrations). If DB credentials change, edit `ppl/config/*.exs` and `block/config/*.exs` together.
- **Run tests**: `cd ppl && MIX_ENV=test mix test`. Add `MIX_ENV=test mix ecto.reset` when fixtures drift.
- **Start gRPC server locally**: `cd ppl && iex -S mix`. Look for `Plumber.Endpoint` in supervision tree; it exposes both Pipeline and Workflow services on the configured port (default see `config/config.exs`).
- **Lint**: `cd ppl && mix credo`.
- **Dialyzer**: `cd ppl && mix dialyzer` (takes a while, usually cached in `_build`).

## Observability Hooks
- Pipeline/Block state changes publish to RabbitMQ exchanges (`pipeline_state_exchange`, `pipeline_block_state_exchange`, `after_pipeline_state_exchange`). Check publisher modules under `ppl/lib/ppl/publishers/` when debugging missing events.
- Triggerers & request tokens are logged via `LogTee`; grep the request token in central logs to correlate gRPC call and DB row.
- Cachex caches YAML, queue stats, etc. Purge via `Cachex.clear/1` while in IEx if stale data blocks you.

## Common Code Paths
- Scheduling: `ppl/lib/ppl/pipeline/scheduler.ex` (entry point from gRPC) → `definition_validator` → DB insert + event publish.
- Termination & stopping: `ppl/lib/ppl/ppls/stm_handler/` (state machine handlers) coordinate with `block/` to stop running jobs.
- Listing: `ppl/lib/ppl/pipelines/query/*.ex` contain Ecto queries; keyset pagination uses the `paginator` library.
- Workflow surface: see `ppl/lib/ppl/workflows/`.

## Gotchas
- Every public response includes `ResponseStatus` / `InternalApi.Status`; handlers must set it even on success. Tests usually assert for `code == :OK`.
- `Schedule`, `ScheduleExtension`, `PartialRebuild`, `Reschedule` all rely on unique `request_token`. Do not skip the idempotency check; see `ppl/lib/ppl/idempotency/`.
- The proto still lists `BlockService.BuildFinished` but the RPC is intentionally disabled—status comes from AMQP. Avoid resurrecting it unless spec changes.
- Pagination mix: offset (`List*`), keyset (`ListKeyset`, `ListGroupedKS`, `ListLatestWorkflows`). Ensure you return both tokens even when empty.
- If you touch migrations remember to run them for both repos (`mix ecto.migrate -r Ppl.EctoRepo -r Block.EctoRepo`).

## Useful Queries
- Describe pipeline: `grpcurl -plaintext -proto proto/plumber.pipeline.proto -d '{"ppl_id":"..."}' localhost:50051 InternalApi.Plumber.PipelineService.Describe`
- Terminate pipeline: same service, `Terminate` RPC. Always include `requester_id`.
- Workflow schedule: `grpcurl ... InternalApi.PlumberWF.WorkflowService.Schedule` (requires repo metadata; easiest to capture from logs/tests).

## When Things Break
1. **Proto mismatch** – regenerate modules (`mix deps.compile proto`). Make sure `proto` app version matches.
2. **DB issues** – inspect `ppl/priv/repo/migrations/` for expected schemas; confirm config in `config/dev.exs`.
3. **State stuck in STOPPING** – review SM handlers in `ppl/lib/ppl/ppls/stm_handler/`, check AMQP event delivery, and ensure block worker acked the stop.
4. **List endpoints slow** – check indices in migrations; pagination queries rely on composite indexes (branch, created_at, etc.).

Keep this file close to the code; update alongside major refactors or schema/proto changes.
