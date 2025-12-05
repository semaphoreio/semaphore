# Plumber Repository Guidelines

## Layout
- `ppl/` hosts the pipeline orchestrator (Elixir/OTP application) together with its GRPC endpoints and database migrations.
- `block/` implements block/task execution logic and is started as a sibling OTP app inside the same release.
- `proto/`, `spec/`, and other top-level folders expose shared protobuf contracts, YAML schemas, and helper libraries.

## Build & Test
- Run `mix deps.get` inside both `ppl/` and `block/` after cloning; each app keeps its own `mix.lock`.
- Use the provided `Makefile` targets (e.g., `make unit-test`) to spin up Postgres/RabbitMQ containers and execute the umbrella test suites.
- Database migrations live under `ppl/priv/ecto_repo/migrations` and `block/priv/ecto_repo/migrations`; run them with `mix ecto.migrate -r <Repo>`.
- All new code must pass `mix credo --strict`, `mix format`, and the relevant `mix test` suites before submitting.

## Development Notes
- Services rely on RabbitMQ (`RABBITMQ_URL`) for event streams; keep it running locally when exercising background workers (e.g., the retention policy consumer).
- Watchman (StatsD) is the default metrics sink; configure `METRICS_HOST`/`METRICS_PORT` for local debugging if needed.

## Documentation
- Service-specific guidance lives under `ppl/AGENTS.md` and `block/AGENTS.md`.
- Architectural notes, including retention policies, are documented in `docs/` (see `docs/pipeline_retention.md` for the event-driven marking flow).
