# Looper

## Overview
Looper is a shared library that provides reusable building blocks for long-running workers inside plumber services. It standardises state-machine loopers (STM), periodic jobs, state residency tracking, and publisher integrations. `ppl` and `block` rely on Looper macros to implement their background schedulers with consistent logging, metrics, and retry semantics.

## Capabilities
- **STM (`Looper.STM`)** – macro that generates GenServer-based schedulers which:
  - Poll Ecto schemas using user-supplied queries.
  - Enforce cooling-off periods between runs.
  - Dispatch handler callbacks for scheduling and termination logic.
  - Publish state transitions via RabbitMQ using the configured callback.
- **Periodic (`Looper.Periodic`)** – DSL for recurring jobs with jitter, backoff, and metrics.
- **State watch/residency (`Looper.StateWatch`, `Looper.StateResidency`)** – helpers that record how long records stay in given states; used for SLA monitoring.
- **Common utilities** – context struct builders (`Looper.Ctx`), query helpers (`Looper.CommonQuery`), benchmarking/logging wrappers (`Looper.Util`).

## How It Fits In
- `ppl/lib/ppl/ppls/stm_handler/*` use `use Looper.STM` to implement pipeline state machines.
- `block/lib/block/blocks/stm_handler/*` and task handlers rely on the same macros to control block execution.
- RabbitMQ publishing hooks plug into Looper’s `publisher_cb` argument to send events after each state transition.
- Metrics are emitted via `Util.Metrics` hooks that Looper invokes automatically when provided.

## Extending Looper
- Implement new behaviour by adding macros in `lib/looper/` and exposing them via documented APIs.
- Ensure new features remain composable—Looper modules are consumed at compile time by other apps.
- Provide sensible defaults via optional arguments in macros to reduce boilerplate for consumers.

## Operations
- Looper is a pure library; no runtime processes beyond what consuming apps spin up.
- Install deps / compile: `cd looper && mix deps.get` (or `mix compile`).
- Run tests: `mix test` (validates helper modules and macros with mocked repos).
- Document macros via inline moduledocs to assist downstream developers.

## Design Notes
- Looper macros expect arguments such as `repo`, `schema`, `initial_query`, `allowed_states`, `publisher_cb`, and `task_supervisor`.
- `Looper.STM` wraps handler callbacks in `Wormhole` for retry and exception capturing.
- Publishing is performed only when state changes; Looper extracts identifiers ending in `_id` to include in events.
- Periodic jobs use `:timer.send_after/2` under the hood; ensure handlers are idempotent.

Keep this document updated when Looper macros gain new capabilities or contract changes so downstream services know how to adapt.
