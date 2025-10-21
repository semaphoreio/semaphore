# Guard Agent Playbook

## Overview
- `Guard` is an Elixir OTP application that fronts user auth, organization lifecycle, and git-provider integrations for Semaphore.
- Primary entry point is `lib/guard/application.ex`; it wires repos, optional feature provider workers, GRPC servers, HTTP Plug endpoints, and Cachex caches based on `START_*` env flags.
- Services expose GRPC APIs (port `50051`/`50052`) and HTTP endpoints (ports `4003`/`4004`) toggled by system env, so inspect those vars before enabling features locally.

## Persistence & Data Shape
- Three Ecto repos: `Guard.Repo`, `Guard.FrontRepo`, and `Guard.InstanceConfigRepo` (all configured via `config/config.exs`). Migrations live in `priv/repo/migrations` and `priv/front_repo/migrations`.
- The main repo embeds schema modules inside `lib/guard/repo.ex` (Users, Collaborators, Projects, ProjectMembers, Suspensions) and additional data-layer logic resides under `lib/guard/store/`.
- Cachex caches (`:ppl_cache`, `:feature_provider_cache`, `:config_cache`) are started conditionally; clear them in tests by dropping the Cachex tables if behaviour appears sticky.

## Domain Map
- `lib/guard/api/` contains external provider clients built with Tesla (`Guard.Api.Github`, `Guard.Api.Bitbucket`, `Guard.Api.Okta`, etc.).
- `lib/guard/grpc_servers/` hosts GRPC server implementations; each wraps protobuf modules from `lib/internal_api/**`.
- `lib/guard/id/`, `lib/guard/oidc/`, `lib/guard/authentication_token.ex`, and `lib/guard/session.ex` compose the HTTP identity endpoints.
- `lib/guard/services/` contains background workers (RabbitMQ consumers, invalidators) supervised by the application.
- `templates/` and `assets/` hold the minimal web UI for login/blocked flows; `priv/` contains persistent resources and embedded repos.

## Local Workflows
- Bootstrap: `mix deps.get && mix compile`.
- Console work: `make console.ex` (starts `iex -S mix` inside the Docker toolchain), or `console.bash` when you need a raw shell.
- Database bootstrap: `make test.ex.setup` (creates/migrates Postgres via docker-compose and seeds broker dependencies).
- Tests: `make test.ex [FILE=path/to/test.exs]` or `mix test`; `mix test.watch` is available for TDD loops. CI uses `JUnitFormatter` (see `test/test_helper.exs`).
- Quality gates: `mix format`, `mix credo --strict`, and `mix sobelow --config .sobelow-conf --exit`. Credo config lives in `.credo.exs`; formatter inputs are defined in `.formatter.exs`.
- Regenerate protobufs after updating `renderedtext/internal_api` definitions with `make pb.gen` (requires Docker access and SSH credentials).

## Testing Toolkit
- Shared fixtures, factories, and Mox mocks live under `test/support/**`; use those instead of rolling bespoke stubs.
- HTTP/service doubles sit in `test/fake` and `test/fixture`, while async scenarios reuse helpers in `test/support/wait.ex` and `test/support/concurrent_repo_case.ex`.
- ExVCR is available for capturing HTTP interactions; prefer deterministic fixtures and keep cassettes under version control if used.

## Configuration Notes
- Base config is in `config/config.exs`; environment-specific overrides live in `config/{dev,test,prod}.exs` and `config/runtime.exs`.
- Many behaviours hinge on env vars exported via the `Makefile` (e.g., `START_GRPC_*`, `START_FEATURE_PROVIDER`, `BASE_DOMAIN`, `AMQP_URL`). Override them in the shell instead of editing config files.
- `docker-compose.yml` describes the dev stack (Elixir app + Postgres 9.6 + RabbitMQ + Adminer); ensure the local Docker daemon runs before invoking `make console.ex`.
- Metrics use `watchman` (StatsD) with namespace `guard.<env>`, and Sentry logging is enabled in production.

## Debugging Patterns
- GRPC servers run under `GRPC.Server.Supervisor`; check logs on ports `50051`/`50052` if clients cannot connect.
- RabbitMQ consumers (`Guard.Services.Organization*`) depend on `AMQP_URL`; missed events usually mean the queue wasn't configured in config or broker is down.
- For OAuth/Git providers, secrets come from `Guard.GitProviderCredentials`; ensure appropriate vault/config entries exist when tokens cannot refresh.
- `Guard.Migrator` offers helper functions for cross-repo migrations—search it when maintaining legacy data.
