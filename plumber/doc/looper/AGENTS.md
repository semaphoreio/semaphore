# Looper Agent Notes

## Core Modules
- `Looper.STM` – macro for state machine workers; takes `repo`, `schema`, `allowed_states`, `publisher_cb`, `task_supervisor`, `cooling_time_sec`.
- `Looper.Periodic` – macro for defining recurring jobs with jitter/backoff.
- `Looper.StateResidency` / `Looper.StateWatch` – track how long records stay in each state.
- `Looper.Util`, `Looper.CommonQuery`, `Looper.Ctx` – helper modules used by generated code.

## Typical Usage
1. Define a module using `use Looper.STM, id: :pipeline_initializing, repo: ..., schema: ...`.
2. Implement callbacks (`scheduling_handler/1`, `terminate_request_handler/2`, etc.).
3. Provide a `publisher_cb` for RabbitMQ if you expect events.
4. Start the module under your supervision tree (see `Ppl.Sup.STM`).

## Commands
- Compile/test only: `cd looper && mix test`.
- Static analysis: `mix credo`.
- Docs (helpful for consumers): `mix docs` (generates moduledoc HTML).

## Debug Tips
- Looper wraps handler calls in `Wormhole.capture`; check Wormhole logs for retries.
- Cooling time set too high blocks scheduling; adjust `cooling_time_sec` in the args map.
- `publisher_cb: :skip` disables event emission—useful for tests.
- All identifiers ending with `_id` are auto-extracted for publisher payloads; ensure structs expose them.
- Looper catches thrown `{:error, reason}` tuples and logs via LogTee; review structured logs when loops halt.

## Extending
- When adding new arguments to macros, ensure backwards compatibility (default options).
- Update consuming services (`ppl`, `block`) once new APIs land.
- Provide tests in `looper/test/` demonstrating the new behaviour.
