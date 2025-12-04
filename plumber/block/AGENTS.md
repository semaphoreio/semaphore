# Block Service Guidelines

## Project Layout
- `lib/block/` contains block request processing, task orchestration, and API clients.
- `priv/ecto_repo/migrations/` stores migrations for `Block.EctoRepo`.
- `config/` defines repo settings, looper timings, and runtime overrides.
- Tests live under `test/`; shared helpers reside in `test/support`.

## Setup & Commands
- Install deps: `mix deps.get`.
- Migrate DB: `mix ecto.migrate -r Block.EctoRepo`.
- Run unit tests: `mix test` (requires Postgres running; use the root Makefile to spin up containers).
- Format/lint: `mix format`, `mix credo --strict`.

## Integration Notes
- Block is started as part of the Plumber release; ensure both repos (`Ppl.EctoRepo` and `Block.EctoRepo`) are migrated.
- RabbitMQ (`RABBITMQ_URL`) is required for task lifecycle events; keep it reachable during development.
- When pipelines are deleted (e.g., via the retention worker) `Block.delete_blocks_from_ppl/1` is invoked to purge block-state tables—be mindful of this coupling when making schema changes.

