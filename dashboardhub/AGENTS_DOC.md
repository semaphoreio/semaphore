# System Overview
- Dashboardhub is a gRPC service for managing project dashboards with public and internal APIs and event publishing. (See: README.md, lib/dashboardhub/grpc/public_api_server.ex, lib/dashboardhub/grpc/internal_api_server.ex, lib/dashboardhub/event.ex)
- It is a single Elixir OTP application that supervises the gRPC endpoint and the Ecto repo. (See: mix.exs, lib/dashboardhub/application.ex, lib/dashboardhub/grpc/endpoint.ex, lib/dashboardhub/repo.ex)
- Deployment artifacts include a Docker release image, local docker-compose for Postgres/RabbitMQ, and a Helm deployment that runs migrations on start. (See: Dockerfile, docker-compose.yml, helm/templates/deployment.yml, lib/dashboardhub/migrator.ex)
- Not fully mapped: this document focuses on the `dashboardhub/` service scope only.

# Architecture Diagram (Text)
```
gRPC clients (public/internal)
        |
        v
Dashboardhub GRPC.Endpoint
  - PublicApiServer / InternalApiServer
  - HealthCheck
        |
        v
Store + Repo (Ecto/Postgres) <-> dashboards table
        |
        v
Event.publish -> AMQP (dashboard_exchange)
```
See: lib/dashboardhub/grpc/endpoint.ex, lib/dashboardhub/grpc/public_api_server.ex, lib/dashboardhub/store.ex, lib/dashboardhub/event.ex, priv/repo/migrations/20180829090323_create_dashboards_table.exs

# Components
## gRPC API Layer (Public/Internal/Health)
- Location (paths): `lib/dashboardhub/grpc/endpoint.ex`, `lib/dashboardhub/grpc/public_api_server.ex`, `lib/dashboardhub/grpc/internal_api_server.ex`, `lib/dashboardhub/grpc/health_check.ex`, `lib/public_api/semaphore/dashboards.v1alpha.pb.ex`, `lib/internal_api/dashboardhub.pb.ex`. (See: lib/dashboardhub/grpc/endpoint.ex, lib/dashboardhub/grpc/public_api_server.ex, lib/dashboardhub/grpc/internal_api_server.ex, lib/dashboardhub/grpc/health_check.ex, lib/public_api/semaphore/dashboards.v1alpha.pb.ex, lib/internal_api/dashboardhub.pb.ex)
- Responsibilities: expose public and internal gRPC APIs for dashboards and a gRPC health check; enforce validation and call downstream storage/event logic. (See: lib/dashboardhub/grpc/public_api_server.ex, lib/dashboardhub/grpc/internal_api_server.ex, lib/dashboardhub/grpc/health_check.ex)
- Entry points: `Dashboardhub.Grpc.Endpoint` is started by `GRPC.Server.Supervisor` in the OTP application; gRPC methods are defined in `PublicApiServer` and `InternalApiServer`. (See: lib/dashboardhub/application.ex, lib/dashboardhub/grpc/endpoint.ex, lib/dashboardhub/grpc/public_api_server.ex, lib/dashboardhub/grpc/internal_api_server.ex)
- Key modules: `Dashboardhub.Grpc.Endpoint`, `Dashboardhub.Grpc.PublicApiServer`, `Dashboardhub.Grpc.InternalApiServer`, `Dashboardhub.Grpc.HealthCheck`, `Dashboardhub.Grpc.SentryInterceptor`. (See: lib/dashboardhub/grpc/endpoint.ex, lib/dashboardhub/grpc/public_api_server.ex, lib/dashboardhub/grpc/internal_api_server.ex, lib/dashboardhub/grpc/health_check.ex, lib/dashboardhub/grpc/interceptors/sentry_interceptor.ex)
- Data stores used: reads/writes dashboards via `Dashboardhub.Store` and `Dashboardhub.Repo` (Postgres). (See: lib/dashboardhub/grpc/public_api_server.ex, lib/dashboardhub/grpc/internal_api_server.ex, lib/dashboardhub/store.ex, lib/dashboardhub/repo.ex)
- External dependencies: `grpc`, `protobuf`, `watchman`, and `sentry` (interceptor). (See: mix.exs, lib/dashboardhub/grpc/interceptors/sentry_interceptor.ex, lib/dashboardhub/grpc/public_api_server.ex)
- How it communicates (HTTP/GRPC/queue/etc.): gRPC server on port 50051 with request metadata headers `x-semaphore-org-id` and `x-semaphore-user-id`. (See: config/config.exs, lib/dashboardhub/grpc/public_api_server.ex)
- Extension points: add new RPCs in `PublicApiServer`/`InternalApiServer` and regenerate protobuf modules via `make pb.gen`. (See: lib/dashboardhub/grpc/public_api_server.ex, lib/dashboardhub/grpc/internal_api_server.ex, Makefile)
- Gotchas: list pagination enforces a max page size of 100; public API extracts org/user IDs from gRPC metadata headers. (See: lib/dashboardhub/public_grpc_api/list_dashboards.ex, lib/dashboardhub/grpc/public_api_server.ex)

## Persistence and Domain Logic (Store/Repo/Utils)
- Location (paths): `lib/dashboardhub/store.ex`, `lib/dashboardhub/repo.ex`, `lib/dashboardhub/utils.ex`, `lib/dashboardhub/public_grpc_api/list_dashboards.ex`, `priv/repo/migrations/20180829090323_create_dashboards_table.exs`. (See: lib/dashboardhub/store.ex, lib/dashboardhub/repo.ex, lib/dashboardhub/utils.ex, lib/dashboardhub/public_grpc_api/list_dashboards.ex, priv/repo/migrations/20180829090323_create_dashboards_table.exs)
- Responsibilities: CRUD dashboards, validate names/widgets, paginate list queries, and map between proto and stored record shapes. (See: lib/dashboardhub/store.ex, lib/dashboardhub/utils.ex, lib/dashboardhub/public_grpc_api/list_dashboards.ex)
- Entry points: `Store.save/3`, `Store.update/4`, `Store.get/2`, `Store.list/1`, `Store.delete/1`, `Repo.Dashboard.changeset/2`, `Utils.proto_to_record/1`, `Utils.record_to_proto/2`. (See: lib/dashboardhub/store.ex, lib/dashboardhub/repo.ex, lib/dashboardhub/utils.ex)
- Key modules: `Dashboardhub.Store`, `Dashboardhub.Repo.Dashboard`, `Dashboardhub.Utils`, `Dashboardhub.PublicGrpcApi.ListDashboards`. (See: lib/dashboardhub/store.ex, lib/dashboardhub/repo.ex, lib/dashboardhub/utils.ex, lib/dashboardhub/public_grpc_api/list_dashboards.ex)
- Data stores used: Postgres table `dashboards` with `org_id`, `name`, `content`, timestamps and unique index on `(org_id, name)`. (See: priv/repo/migrations/20180829090323_create_dashboards_table.exs, lib/dashboardhub/repo.ex)
- External dependencies: Ecto/Postgrex, Paginator, Poison. (See: mix.exs, lib/dashboardhub/repo.ex, lib/dashboardhub/public_grpc_api/list_dashboards.ex, lib/dashboardhub/utils.ex)
- How it communicates (HTTP/GRPC/queue/etc.): Ecto queries through `Dashboardhub.Repo` and cursor pagination via `Repo.paginate`. (See: lib/dashboardhub/store.ex, lib/dashboardhub/public_grpc_api/list_dashboards.ex)
- Extension points: add new fields in the schema and migration, and update `Utils.record_to_proto/2` and `Utils.proto_to_record/1` for new fields. (See: lib/dashboardhub/repo.ex, priv/repo/migrations/20180829090323_create_dashboards_table.exs, lib/dashboardhub/utils.ex)
- Gotchas: `Store.get/2` chooses ID vs name based on `Utils.uuid?/1`; names cannot be UUID-like and must match the lowercase/slug regex. (See: lib/dashboardhub/store.ex, lib/dashboardhub/repo.ex, lib/dashboardhub/utils.ex)

## Event Publishing (AMQP/Tackle)
- Location (paths): `lib/dashboardhub/event.ex`, `lib/dashboardhub/events/publisher.ex`, `lib/dashboardhub/events/dashboard_created.ex`, `lib/dashboardhub/events/dashboard_updated.ex`, `lib/dashboardhub/events/dashboard_deleted.ex`. (See: lib/dashboardhub/event.ex, lib/dashboardhub/events/publisher.ex, lib/dashboardhub/events/dashboard_created.ex, lib/dashboardhub/events/dashboard_updated.ex, lib/dashboardhub/events/dashboard_deleted.ex)
- Responsibilities: build `InternalApi.Dashboardhub.DashboardEvent` payloads and publish them to RabbitMQ with routing keys. (See: lib/dashboardhub/event.ex, lib/dashboardhub/events/publisher.ex)
- Entry points: `Dashboardhub.Event.publish/3` (used by gRPC handlers); `Dashboardhub.Events.*.publish/1` wrappers using AMQP channels. (See: lib/dashboardhub/event.ex, lib/dashboardhub/grpc/public_api_server.ex, lib/dashboardhub/grpc/internal_api_server.ex, lib/dashboardhub/events/dashboard_created.ex)
- Key modules: `Dashboardhub.Event`, `Dashboardhub.Events.Publisher`, `Dashboardhub.Events.DashboardCreated`, `Dashboardhub.Events.DashboardUpdated`, `Dashboardhub.Events.DashboardDeleted`. (See: lib/dashboardhub/event.ex, lib/dashboardhub/events/publisher.ex, lib/dashboardhub/events/dashboard_created.ex, lib/dashboardhub/events/dashboard_updated.ex, lib/dashboardhub/events/dashboard_deleted.ex)
- Data stores used: none. (See: lib/dashboardhub/event.ex)
- External dependencies: `tackle`, `amqp`, and `InternalApi.Dashboardhub.DashboardEvent`. (See: mix.exs, lib/dashboardhub/event.ex, lib/dashboardhub/events/publisher.ex)
- How it communicates (HTTP/GRPC/queue/etc.): publishes to RabbitMQ exchange `dashboard_exchange` using `AMQP_URL` from runtime config. (See: lib/dashboardhub/event.ex, config/runtime.exs)
- Extension points: extend `Dashboardhub.Event.validate/1` and update payload fields if new event types are introduced. (See: lib/dashboardhub/event.ex)
- Gotchas: `Dashboardhub.Event.publish/3` only accepts routing keys `created`, `updated`, `deleted`; AMQP must be configured to avoid publish failures. (See: lib/dashboardhub/event.ex, config/runtime.exs)

# Data Model & Persistence
- Primary datastore is Postgres with a single `dashboards` table storing `org_id`, `name`, `content`, and timestamps; unique index enforces per-org unique names. (See: priv/repo/migrations/20180829090323_create_dashboards_table.exs)
- Ecto schema and changeset validations live in `Dashboardhub.Repo.Dashboard`, including name format and uniqueness. (See: lib/dashboardhub/repo.ex)
- List pagination uses cursor-based pagination via `Repo.paginate` and returns `next_page_token`. (See: lib/dashboardhub/public_grpc_api/list_dashboards.ex)

# Request / Job Flows
- Public gRPC create_dashboard -> extract org/user headers -> Auth.authorize -> Utils.valid_widgets? -> Store.save -> Event.publish("created") -> encode to proto response. (See: lib/dashboardhub/grpc/public_api_server.ex, lib/dashboardhub/auth.ex, lib/dashboardhub/utils.ex, lib/dashboardhub/store.ex, lib/dashboardhub/event.ex)
- Public gRPC list_dashboards -> extract page_size -> ListDashboards.query -> Repo.paginate -> ListDashboardsResponse with next_page_token. (See: lib/dashboardhub/grpc/public_api_server.ex, lib/dashboardhub/public_grpc_api/list_dashboards.ex, lib/dashboardhub/repo.ex)
- Internal gRPC update -> Store.get -> Utils.valid_widgets? -> Store.update -> Event.publish("updated") -> UpdateResponse. (See: lib/dashboardhub/grpc/internal_api_server.ex, lib/dashboardhub/store.ex, lib/dashboardhub/utils.ex, lib/dashboardhub/event.ex)
- Health check -> HealthCheck.check returns SERVING status. (See: lib/dashboardhub/grpc/health_check.ex)

# Configuration & Environments
- Compile-time config and environment overrides live in `config/config.exs` and `config/{dev,test,prod}.exs`, with runtime env wiring in `config/runtime.exs`. (See: config/config.exs, config/dev.exs, config/test.exs, config/prod.exs, config/runtime.exs)
- Required runtime env vars include DB connection (`POSTGRES_DB_*`), AMQP URL, log level, and optional Sentry configuration. (See: config/runtime.exs, docker-compose.yml, Makefile)
- gRPC enablement and port are controlled by `GRPC_API` and `grpc_port` config. (See: lib/dashboardhub/application.ex, config/config.exs, docker-compose.yml)
- Migrations path is configurable via `MIGRATIONS_PATH` for release deployments. (See: config/runtime.exs, lib/dashboardhub/migrator.ex)

# Infrastructure & Deployment (as implemented here)
- Dockerfile builds a multi-stage release image and runs `dashboardhub` as a non-root user. (See: Dockerfile)
- Base image versions for build/run are set via Dockerfile ARGs (`ELIXIR_VERSION`, `OTP_VERSION`, `ALPINE_VERSION`). (See: Dockerfile)
- Local development uses docker-compose with Postgres 9.6 and RabbitMQ plus gRPC port 50051. (See: docker-compose.yml)
- Helm deployment exposes gRPC on port 50051 and runs migrations on start with `Dashboardhub.Release.migrate()`. (See: helm/templates/deployment.yml, lib/dashboardhub/migrator.ex)
- Protobuf stubs are generated from external repos via `make pb.gen` into `lib/internal_api` and `lib/public_api`. (See: Makefile, lib/internal_api/dashboardhub.pb.ex, lib/public_api/semaphore/dashboards.v1alpha.pb.ex)

# Testing Strategy (as implemented here)
- ExUnit tests live under `test/dashboardhub` and cover internal and public gRPC APIs. (See: test/dashboardhub/internal_grpc_api_test.exs, test/dashboardhub/public_grpc_api_test.exs)
- Test configuration uses `test/test_helper.exs` with optional JUnit formatting in CI. (See: test/test_helper.exs)
- Local test runs are orchestrated via the `Makefile` and create/migrate the DB with docker-compose. (See: Makefile)

# Observability
- Logging uses `Logger` in gRPC handlers and runtime log level is controlled by `LOG_LEVEL`. (See: lib/dashboardhub/grpc/public_api_server.ex, lib/dashboardhub/grpc/internal_api_server.ex, config/runtime.exs)
- Sentry is wired through a gRPC interceptor and the Logger backend in prod. (See: lib/dashboardhub/grpc/interceptors/sentry_interceptor.ex, lib/dashboardhub/application.ex, config/runtime.exs)
- Metrics are emitted via Watchman benchmarks in list/query flows. (See: lib/dashboardhub/grpc/public_api_server.ex, lib/dashboardhub/public_grpc_api/list_dashboards.ex, config/runtime.exs)

# "How to Extend" Playbooks
- Add a new gRPC endpoint: update protobuf definitions (then regenerate with `make pb.gen`), add a handler in `PublicApiServer` or `InternalApiServer`, and extend `Utils.record_to_proto/2` or `Utils.proto_to_record/1` as needed. (See: Makefile, lib/dashboardhub/grpc/public_api_server.ex, lib/dashboardhub/grpc/internal_api_server.ex, lib/dashboardhub/utils.ex, lib/public_api/semaphore/dashboards.v1alpha.pb.ex, lib/internal_api/dashboardhub.pb.ex)
- Add a new DB table/migration: create a migration in `priv/repo/migrations`, define a new schema or update `Dashboardhub.Repo.Dashboard`, and ensure release migrations run via `Dashboardhub.Release.migrate()`. (See: priv/repo/migrations/20180829090323_create_dashboards_table.exs, lib/dashboardhub/repo.ex, lib/dashboardhub/migrator.ex, helm/templates/deployment.yml)
- Add a new config option: declare defaults in `config/config.exs`, wire env vars in `config/runtime.exs`, and expose them in docker-compose/Helm env blocks if needed. (See: config/config.exs, config/runtime.exs, docker-compose.yml, helm/templates/deployment.yml)
- Add a background worker: there is no dedicated job framework; add a supervised worker under `Dashboardhub.Application` and reuse existing supervision patterns. (See: lib/dashboardhub/application.ex)

# Appendix: Index of Important Files
- See: `README.md` - service description and top-level commands.
- See: `lib/dashboardhub/application.ex` - OTP entry point and supervision tree.
- See: `lib/dashboardhub/grpc/endpoint.ex` - gRPC endpoint wiring and interceptors.
- See: `lib/dashboardhub/grpc/public_api_server.ex` - public gRPC API handlers.
- See: `lib/dashboardhub/grpc/internal_api_server.ex` - internal gRPC API handlers.
- See: `lib/dashboardhub/store.ex` - persistence logic for dashboards.
- See: `lib/dashboardhub/repo.ex` - Ecto Repo and dashboard schema/changeset.
- See: `lib/dashboardhub/utils.ex` - proto/record mapping and widget validation.
- See: `lib/dashboardhub/event.ex` - event publishing logic.
- See: `lib/dashboardhub/migrator.ex` - release migration runner.
- See: `priv/repo/migrations/20180829090323_create_dashboards_table.exs` - schema definition for dashboards.
- See: `config/config.exs` - base config and gRPC port.
- See: `config/runtime.exs` - runtime env configuration.
- See: `Dockerfile` - build and release image.
- See: `docker-compose.yml` - local dependencies and env defaults.
- See: `helm/templates/deployment.yml` - Kubernetes deployment config.
