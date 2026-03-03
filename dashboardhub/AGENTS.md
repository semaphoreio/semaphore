# Overview
- Dashboardhub is a gRPC service for managing project dashboards with internal/public APIs, authentication, and event handling. (See: README.md)
- Runtime targets: Elixir "~> 1.14" (mix.exs), Docker uses Elixir 1.14.5/OTP 25.3.2.21 on Alpine 3.22.2 (Dockerfile); local deps via Docker Compose use Postgres 9.6 and RabbitMQ 3-management (docker-compose.yml).
- Primary docs and deployment config live in the service README and Helm chart. (See: README.md, helm/templates/deployment.yml)

# Golden Rules (Must Follow)
- Run formatter and lint before shipping: `make format.ex` and `make lint.ex` (../Makefile); CI enforces these targets. (See: .semaphore/semaphore.yml)
- Run tests via `make test.ex`; CI runs the same target for Dashboardhub QA. (See: ../Makefile, .semaphore/semaphore.yml)
- Regenerate protobuf stubs with `make pb.gen` when changing API protos; it overwrites `lib/internal_api` and `lib/public_api`. (See: Makefile)
- Keep secrets/config in env vars (DB, AMQP, Sentry) instead of hardcoding. (See: config/runtime.exs, docker-compose.yml)
- Prefer the Docker-based workflow used by Makefile/CI to keep builds consistent. (See: Makefile, ../Makefile)
- Check `AGENTS_DOC.md` for architecture and flow details when planning or implementing changes. (See: AGENTS_DOC.md)

# Repo Map (High Level)
- `config/`: app config by env and runtime env var wiring. (See: config/config.exs, config/runtime.exs)
- `lib/`: core app code (OTP app, gRPC endpoint/servers, repo, events). Entrypoints: `lib/dashboardhub/application.ex`, `lib/dashboardhub/grpc/endpoint.ex`.
- `lib/internal_api/` and `lib/public_api/`: generated gRPC protobuf modules. (See: Makefile)
- `priv/repo/migrations/`: Ecto migrations for Postgres. (See: priv/repo/migrations/20180829090323_create_dashboards_table.exs)
- `test/`: ExUnit tests and helpers. (See: test/test_helper.exs)
- `helm/`: Kubernetes deployment chart, including migration-on-start. (See: helm/templates/deployment.yml)
- `Dockerfile`, `docker-compose.yml`, `Makefile`: container build and local dev/test wiring.
- `_build/`, `deps/`: Mix build artifacts created by build/test targets. (See: ../Makefile, Makefile)

# Build, Run, Test
- Prereqs: Docker + Docker Compose + Make; Make targets run inside containers. (See: Makefile, ../Makefile, docker-compose.yml)
- Build image: `make build` (../Makefile).
- Interactive dev shell: `make console.ex` for IEx or `make dev.console` for bash. (See: ../Makefile, Makefile)
- Compile deps quickly: `make compile`. (See: Makefile)
- Tests: `make test.ex` (../Makefile). Locally this runs `mix do ecto.create, ecto.migrate` via `test.ex.setup`. (See: Makefile)
- Formatting/lint: `make format.ex` and `make lint.ex`. (See: ../Makefile, .formatter.exs, .credo.exs)
- Test reports: CI enables JUnit formatter and writes to `./out/test-reports.xml`. (See: test/test_helper.exs, config/test.exs)
- CI summary (Dashboardhub): builds test/prod images, runs format/credo/tests, and security checks `check.ex.code`, `check.ex.deps`, `check.docker`. (See: .semaphore/semaphore.yml, ../Makefile)

# Coding Conventions
- Use Ecto schemas/changesets for validation; dashboards use `binary_id` primary keys and validate required fields in `Dashboardhub.Repo.Dashboard`. (See: lib/dashboardhub/repo.ex)
- gRPC services are registered through `Dashboardhub.Grpc.Endpoint` with interceptors (Sentry) for error capture. (See: lib/dashboardhub/grpc/endpoint.ex, lib/dashboardhub/grpc/interceptors/sentry_interceptor.ex)
- Feature flags/config are driven by env vars at runtime (`GRPC_API`, DB/AMQP settings) and read via `Application.get_env`/`System.get_env`. (See: lib/dashboardhub/application.ex, config/runtime.exs)
- Use Logger for runtime logging; prod adds Sentry LoggerBackend. (See: lib/dashboardhub/application.ex, config/dev.exs, config/runtime.exs)

# Dependency & Tooling Management
- Elixir deps are managed in `mix.exs` with lockfile `mix.lock`. (See: mix.exs, mix.lock)
- Formatting and linting are configured in `.formatter.exs` and `.credo.exs`; run via Make targets. (See: .formatter.exs, .credo.exs, ../Makefile)
- Protobuf generation uses Dockerized `protoc` and clones external proto repos; run `make pb.gen`. (See: Makefile)
- Container builds and local services use `Dockerfile` and `docker-compose.yml`. (See: Dockerfile, docker-compose.yml)

# Database / Storage (if applicable)
- Postgres via Ecto Repo `Dashboardhub.Repo`; connection settings are env-driven. (See: lib/dashboardhub/repo.ex, config/runtime.exs)
- Migrations live in `priv/repo/migrations` and are run with `mix ecto.migrate` (invoked in `test.ex.setup`). (See: priv/repo/migrations/20180829090323_create_dashboards_table.exs, Makefile)
- Release/Helm runs migrations on startup via `Dashboardhub.Release.migrate()`. (See: lib/dashboardhub/migrator.ex, helm/templates/deployment.yml)
- Seeds or DB reset flow: Unknown / verify (no seed scripts found).

# Observability / Debugging
- Logging level is controlled by `LOG_LEVEL`; dev/test default to `:debug`. (See: config/runtime.exs, config/dev.exs, config/test.exs)
- Sentry is configured via env vars and used in the gRPC interceptor plus Logger backend. (See: config/runtime.exs, lib/dashboardhub/grpc/interceptors/sentry_interceptor.ex, lib/dashboardhub/application.ex)
- Metrics emit via Watchman/StatsD with `METRICS_NAMESPACE`. (See: config/runtime.exs)
- Health checks are served by the gRPC endpoint. (See: lib/dashboardhub/grpc/endpoint.ex)

# Security / Compliance
- Secrets are provided via env vars (DB creds, AMQP URL, Sentry DSN); avoid hardcoding. (See: config/runtime.exs, docker-compose.yml)
- Docker/Helm harden runtime: non-root user in Dockerfile; Helm drops capabilities and enables read-only root FS. (See: Dockerfile, helm/templates/deployment.yml)
- Security scanners configured: Sobelow config `.sobelow-conf` and Trivy ignore policy `security-ignore-policy.rego`; CI runs `check.ex.code`, `check.ex.deps`, `check.docker`. (See: .sobelow-conf, security-ignore-policy.rego, .semaphore/semaphore.yml, ../Makefile)

# PR Checklist
- Run `make format.ex` and `make lint.ex`. (See: ../Makefile, .formatter.exs, .credo.exs)
- Run `make test.ex` and ensure migrations pass locally. (See: ../Makefile, Makefile)
- If protobufs changed, run `make pb.gen` and commit generated modules. (See: Makefile)
- If DB schema changes, add a migration under `priv/repo/migrations` and verify release migration path. (See: priv/repo/migrations/20180829090323_create_dashboards_table.exs, lib/dashboardhub/migrator.ex)
- If container/deployment changes, ensure Docker build and Helm expectations still hold. (See: Dockerfile, helm/templates/deployment.yml)
