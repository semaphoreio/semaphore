# Ppl Service Guidelines

## Project Layout
- `lib/ppl/` contains the OTP application code (workers, GRPC servers, caches, etc.).
- `priv/ecto_repo/migrations/` holds database migrations for `Ppl.EctoRepo`.
- `config/` hosts the environment-specific config (runtime DB credentials, Watchman, RabbitMQ consumers).
- `test/` mirrors `lib/` with ExUnit suites; helpers live in `test/support`.

## Common Tasks
- Install deps: `mix deps.get`.
- Run migrations: `mix ecto.migrate -r Ppl.EctoRepo`.
- Launch tests: `mix test` (set `MIX_ENV=test`, and start Postgres/RabbitMQ via the repo `Makefile` if not already running).
- Format & lint: `mix format`, `mix credo --strict`.

## Background Workers
- Looper STMs and Beholders are supervised via `Ppl.Application`.
- `Ppl.Retention.PolicyConsumer` (Tackle) listens for `usage.OrganizationPolicyApply` events and marks pipelines by setting `expires_at`.

## Configuration Tips
- StatsD via Watchman: set `METRICS_HOST`, `METRICS_PORT`, `METRICS_NAMESPACE`.
- DB settings: `POSTGRES_DB_*` env vars control `Ppl.EctoRepo`; separate vars govern the `block` repo.
- Retention consumer: `USAGE_POLICY_EXCHANGE` / `USAGE_POLICY_ROUTING_KEY` configure which RabbitMQ route the policy consumer listens to.

## Commit Format

Use conventional commits with tagged lines for categorizing changes:

```text
feat(plumber): short description

[db] Database changes (migrations, indexes, schema)
[worker] Background worker changes (consumers, loopers, beholders)
[api] API changes (GRPC servers, endpoints)
[config] Configuration changes (env vars, runtime config)
```

Tags: `[db]`, `[worker]`, `[api]`, `[config]`, `[test]`, `[docs]`
