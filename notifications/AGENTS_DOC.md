# AGENTS_DOC.md

## System Overview
- Notifications is an Elixir OTP service that manages notification rules and delivers Slack/webhook notifications for Semaphore 2.0. See: `README.md`, `docs/specs.md`.
- Architecture: gRPC APIs + AMQP consumers + delivery workers backed by Postgres and RabbitMQ. See: `docs/arch.md`, `lib/notifications/application.ex`, `docker-compose.yml`.
- Deployment model is a Mix release packaged in Docker; local dev uses docker compose. See: `Dockerfile`, `docker-compose.yml`.
- Scope note: this document maps `notifications/` only; generated proto modules under `lib/internal_api` and `lib/public_api` are not fully mapped. See: `lib/internal_api`, `lib/public_api`, `scripts/internal_protos.sh`, `scripts/public_protos.sh`.

## Architecture Diagram (Text)
```text
[Clients] --gRPC--> Public API (Notifications.Api.PublicApi) --> Postgres (Notifications.Repo)
[Internal services] --gRPC--> Internal API (Notifications.Api.InternalApi) --> Postgres

Pipeline finished events (RabbitMQ: pipeline_state_exchange/done)
  -> Coordinator (PipelineFinished)
     -> gRPC fetch (Projecthub/Plumber/RepoProxy/Workflow/Organization)
     -> Rule filter (patterns) -> Slack/Webhook HTTP

Organization deleted events (RabbitMQ: organization_exchange/deleted)
  -> Destroyer -> DB delete
```
See: `docs/arch.md`, `lib/notifications/application.ex`, `lib/notifications/workers/coordinator.ex`, `lib/notifications/workers/coordinator/api.ex`, `lib/notifications/workers/destroyer.ex`.

## Components

### Notifications Application (Supervisor)
- Location: `lib/notifications/application.ex`.
- Responsibilities: start Repo, AMQP consumers, and conditional gRPC server; configure logger filters and Sentry backend. See: `lib/notifications/application.ex`, `config/config.exs`.
- Entry points / interface: `start/2` and `GRPC.Server.Supervisor` on port 50051. See: `lib/notifications/application.ex`.
- Key modules: `Notifications.Repo`, `Notifications.Workers.Coordinator.PipelineFinished`, `Notifications.Workers.Destroyer`, `Notifications.Api.PublicApi`, `Notifications.Api.InternalApi`. See: `lib/notifications/application.ex`.
- Data stores & communication: Postgres via `Notifications.Repo` and gRPC server for APIs. See: `lib/notifications/repo.ex`, `lib/notifications/application.ex`.
- Extension points / gotchas: add new workers or gRPC services to `children`; gRPC APIs only start in test or when `START_PUBLIC_API`/`START_INTERNAL_API` are set; Sentry backend only in non-dev/test. See: `lib/notifications/application.ex`.

### Public gRPC API
- Location: `lib/notifications/api/public_api.ex` and `lib/notifications/api/public_api/*`.
- Responsibilities: CRUD notifications for external clients; enforce RBAC and validation; serialize Ecto models to public proto. See: `lib/notifications/api/public_api/create.ex`, `lib/notifications/api/public_api/serialization.ex`.
- Entry points / interface: `Notifications.Api.PublicApi` implements `Semaphore.Notifications.V1alpha.NotificationsApi.Service` functions like `list_notifications` and `create_notification`. See: `lib/notifications/api/public_api.ex`.
- Key modules & dependencies: `Notifications.Auth`, `Notifications.Util.Validator`, `Notifications.Util.Transforms`, `Notifications.Util.RuleFactory`, `Notifications.Api.PublicApi.Serialization`. See: `lib/notifications/auth.ex`, `lib/notifications/util/validator.ex`, `lib/notifications/util/transforms.ex`, `lib/notifications/util/rule_factory.ex`.
- Data stores & communication: Postgres via `Notifications.Repo` and models; gRPC types from `lib/public_api`. See: `lib/notifications/models/notification.ex`, `lib/notifications/repo.ex`, `lib/public_api`.
- Extension points / gotchas: headers `x-semaphore-org-id` and `x-semaphore-user-id` are required; proto changes require `make pb.gen`. See: `lib/notifications/api/public_api.ex`, `Makefile`, `scripts/public_protos.sh`.

### Internal gRPC API
- Location: `lib/notifications/api/internal_api.ex` and `lib/notifications/api/internal_api/*`.
- Responsibilities: CRUD/list/describe notifications for internal services; validate input and serialize to InternalApi protos. See: `lib/notifications/api/internal_api/create.ex`, `lib/notifications/api/internal_api/serialization.ex`.
- Entry points / interface: `Notifications.Api.InternalApi` implements `InternalApi.Notifications.NotificationsApi.Service` functions `list`, `describe`, `create`, `update`, `destroy`. See: `lib/notifications/api/internal_api.ex`.
- Key modules & dependencies: internal_api handlers, `Notifications.Util.Validator`, `Notifications.Util.RuleFactory`. See: `lib/notifications/api/internal_api/*`, `lib/notifications/util/validator.ex`, `lib/notifications/util/rule_factory.ex`.
- Data stores & communication: Postgres via `Notifications.Repo`; gRPC types from `lib/internal_api`. See: `lib/notifications/repo.ex`, `lib/internal_api`.
- Extension points / gotchas: no RBAC checks in internal API code; org/user IDs come from `req.metadata`; proto changes require `make pb.gen`. See: `lib/notifications/api/internal_api/create.ex`, `Makefile`, `scripts/internal_protos.sh`.

### Coordinator (PipelineFinished) Worker
- Location: `lib/notifications/workers/coordinator.ex`, `lib/notifications/workers/coordinator/api.ex`, `lib/notifications/workers/coordinator/filter.ex`.
- Responsibilities: consume pipeline finished events, fetch pipeline/project/hook/workflow/org data via gRPC, filter rules/patterns, publish to Slack/Webhook. See: `lib/notifications/workers/coordinator.ex`.
- Entry points / interface: `Notifications.Workers.Coordinator.PipelineFinished.handle_message/1`. See: `lib/notifications/workers/coordinator.ex`.
- Key modules & dependencies: `Tackle.Consumer` (AMQP), `Notifications.Workers.Coordinator.Api`, `Notifications.Workers.Coordinator.Filter`, `Notifications.Auth`, `Notifications.Workers.Slack`, `Notifications.Workers.Webhook`. See: `lib/notifications/workers/coordinator.ex`, `lib/notifications/workers/coordinator/api.ex`, `lib/notifications/workers/coordinator/filter.ex`.
- Data stores & communication: reads Postgres rules/patterns; AMQP exchange `pipeline_state_exchange` routing key `done`; gRPC calls to Projecthub/Plumber/RepoProxy/Workflow/Organization endpoints from runtime config. See: `lib/notifications/workers/coordinator.ex`, `lib/notifications/workers/coordinator/api.ex`, `config/runtime.exs`.
- Extension points / gotchas: filtering uses SQL fragments with regex flags; new filter types require updates in `RuleFactory` and `Coordinator.Filter`; authorization uses RBAC `project.view`. See: `lib/notifications/util/rule_factory.ex`, `lib/notifications/workers/coordinator/filter.ex`, `lib/notifications/auth.ex`.

### Destroyer Worker
- Location: `lib/notifications/workers/destroyer.ex`.
- Responsibilities: consume organization deletion events and delete related notifications. See: `lib/notifications/workers/destroyer.ex`.
- Entry points / interface: `handle_message/1`. See: `lib/notifications/workers/destroyer.ex`.
- Data stores & communication: deletes from Postgres via `Notifications.Repo`; consumes AMQP exchange `organization_exchange` routing key `deleted`. See: `lib/notifications/workers/destroyer.ex`.
- External dependencies: `Tackle.Consumer`, `Watchman`, `Logger`. See: `lib/notifications/workers/destroyer.ex`.
- Extension points / gotchas: add cleanup for other org-scoped tables here; errors are caught and re-raised with metrics. See: `lib/notifications/workers/destroyer.ex`.

### Delivery Workers (Slack/Webhook/Email)
- Location: `lib/notifications/workers/slack.ex`, `lib/notifications/workers/slack/message.ex`, `lib/notifications/workers/webhook.ex`, `lib/notifications/workers/webhook/*`, `lib/notifications/workers/email.ex`.
- Responsibilities: construct and deliver Slack/webhook payloads; email worker is a stub. See: `lib/notifications/workers/slack.ex`, `lib/notifications/workers/webhook.ex`, `lib/notifications/workers/email.ex`.
- Entry points / interface: `publish/4` in Slack/Webhook; message builders in `*.Message` modules. See: `lib/notifications/workers/slack.ex`, `lib/notifications/workers/webhook.ex`, `lib/notifications/workers/slack/message.ex`, `lib/notifications/workers/webhook/message.ex`.
- External dependencies: HTTPoison for HTTP requests, Secrethub gRPC for webhook secrets, Watchman for metrics, crypto for signatures. See: `lib/notifications/workers/webhook.ex`, `lib/notifications/workers/webhook/secret.ex`, `lib/notifications/workers/webhook/signature.ex`.
- Data stores & communication: no DB usage; HTTP POST to Slack/webhook endpoints; gRPC to Secrethub for secret fetch. See: `lib/notifications/workers/slack.ex`, `lib/notifications/workers/webhook/secret.ex`.
- Extension points / gotchas: webhook uses `settings.action` as HTTP method (default "post"), retries on timeouts with exponential backoff, and adds `X-Semaphore-Signature-256` only when secret is present; email worker has no implementation yet. See: `lib/notifications/workers/webhook.ex`, `lib/notifications/workers/email.ex`.

### Persistence Layer (Repo + Models)
- Location: `lib/notifications/repo.ex`, `lib/notifications/models/*`, `priv/repo/migrations/*`.
- Responsibilities: Ecto schemas and changesets for notifications/rules/patterns; query helpers; rule/pattern creation in `Notifications.Util.RuleFactory`. See: `lib/notifications/models/notification.ex`, `lib/notifications/models/rule.ex`, `lib/notifications/models/pattern.ex`, `lib/notifications/util/rule_factory.ex`.
- Entry points / interface: `Notifications.Repo`, `Notifications.Models.Notification.find_*`, `Notifications.Models.Rule`, `Notifications.Models.Pattern`. See: `lib/notifications/repo.ex`, `lib/notifications/models/notification.ex`, `lib/notifications/models/rule.ex`, `lib/notifications/models/pattern.ex`.
- Data stores & communication: Postgres via Ecto/Postgrex. See: `config/runtime.exs`, `lib/notifications/repo.ex`.
- Key dependencies: Ecto, Paginator, Util.Proto transforms for spec storage. See: `mix.exs`, `lib/notifications/util/transforms.ex`.
- Extension points / gotchas: notification names cannot be UUID format and must be unique per org; patterns can be regex (`/pattern/`) or exact match and are used in SQL fragments for filtering; `Patterns.changeset/2` casts fields not present in its schema (verify before reusing). See: `lib/notifications/models/notification.ex`, `lib/notifications/models/pattern.ex`, `lib/notifications/workers/coordinator/filter.ex`.

### Utilities & Validation
- Location: `lib/notifications/util/*`.
- Responsibilities: input validation, proto-map transforms, rule/pattern persistence helpers. See: `lib/notifications/util/validator.ex`, `lib/notifications/util/transforms.ex`, `lib/notifications/util/rule_factory.ex`.
- Entry points / interface: `Notifications.Util.Validator.validate/2`, `Notifications.Util.Transforms.encode_spec/1`, `Notifications.Util.RuleFactory.persist_rules/2`. See: `lib/notifications/util/validator.ex`, `lib/notifications/util/transforms.ex`, `lib/notifications/util/rule_factory.ex`.
- Data stores & communication: uses Repo when persisting rules and patterns; no external I/O otherwise. See: `lib/notifications/util/rule_factory.ex`.
- External dependencies: Ecto.UUID, Util.Proto, generated proto modules. See: `lib/notifications/util/validator.ex`, `lib/notifications/util/transforms.ex`.
- Extension points / gotchas: validator enforces at least one notify target and validates regex and result values; update validation when adding new filter fields or result enums. See: `lib/notifications/util/validator.ex`.

## Data Model & Persistence
- Postgres is the only datastore, configured via env vars for `Notifications.Repo`. See: `lib/notifications/repo.ex`, `config/runtime.exs`.
- `notifications` table: `id`, `org_id`, `name`, `spec` (map), `creator_id` (nullable) with unique index on `{org_id, name}`. See: `priv/repo/migrations/20180619115727_create_notiications_table.exs`, `priv/repo/migrations/20250804163141_add_creator_id_to_notifications.exs`, `lib/notifications/models/notification.ex`.
- `rules` table: `notification_id` FK, `org_id`, `name`, and `slack`/`email`/`webhook` maps. See: `priv/repo/migrations/20181031101331_add_rules_table.exs`, `lib/notifications/models/rule.ex`.
- `patterns` table: `rule_id` FK, `term`, `type`, `regex` for filtering. See: `priv/repo/migrations/20181031102106_add_patterns_table.exs`, `lib/notifications/models/pattern.ex`, `lib/notifications/workers/coordinator/filter.ex`.
- Relationships: Notification has many Rules; Rule has many Patterns with delete cascades. See: `lib/notifications/models/notification.ex`, `lib/notifications/models/rule.ex`, `lib/notifications/models/pattern.ex`.
- Release migrations: `Notifications.Release` uses `:migrations_path` from runtime config. See: `lib/notifications/migration.ex`, `config/runtime.exs`.

## Request / Job Flows
- Public API create notification: gRPC -> `Notifications.Api.PublicApi.create_notification/2` -> `PublicApi.Create.run` -> `Auth.can_manage?/2` -> `Validator.validate/2` -> `Repo.transaction` -> `Notification.new` + `Repo.insert` -> `RuleFactory.persist_rules` -> `Serialization.serialize`. See: `lib/notifications/api/public_api.ex`, `lib/notifications/api/public_api/create.ex`, `lib/notifications/auth.ex`, `lib/notifications/util/validator.ex`, `lib/notifications/util/rule_factory.ex`, `lib/notifications/api/public_api/serialization.ex`.
- Internal API create notification: gRPC -> `Notifications.Api.InternalApi.create/2` -> `InternalApi.Create.run` -> `Validator.validate/2` -> `Repo.transaction` -> `Notification.new` + `RuleFactory.persist_rules`. See: `lib/notifications/api/internal_api.ex`, `lib/notifications/api/internal_api/create.ex`, `lib/notifications/util/validator.ex`, `lib/notifications/util/rule_factory.ex`.
- Pipeline finished event: AMQP `pipeline_state_exchange/done` -> `Coordinator.PipelineFinished.handle_message/1` -> gRPC lookups -> `Coordinator.Filter.find_rules` -> authorize -> Slack/Webhook publish. See: `lib/notifications/workers/coordinator.ex`, `lib/notifications/workers/coordinator/api.ex`, `lib/notifications/workers/coordinator/filter.ex`, `lib/notifications/workers/slack.ex`, `lib/notifications/workers/webhook.ex`.
- Webhook delivery: `Webhook.publish/3` -> `Webhook.Message.construct` -> sign via `Webhook.Signature` using Secrethub secret -> HTTP request with retry/backoff. See: `lib/notifications/workers/webhook.ex`, `lib/notifications/workers/webhook/message.ex`, `lib/notifications/workers/webhook/signature.ex`, `lib/notifications/workers/webhook/secret.ex`.
- Organization deleted event: AMQP `organization_exchange/deleted` -> `Destroyer.handle_message/1` -> delete notifications by org. See: `lib/notifications/workers/destroyer.ex`, `lib/notifications/models/notification.ex`.

## Configuration & Environments
- Config layering: `config/config.exs` sets base config and imports env-specific files; `config/runtime.exs` sets runtime env-based configuration; `config/dev.exs` and `config/prod.exs` are currently empty. See: `config/config.exs`, `config/runtime.exs`, `config/dev.exs`, `config/prod.exs`.
- Test config: gRPC endpoints are pointed at localhost, Repo uses SQL sandbox, JUnit formatter is configured. See: `config/test.exs`, `test/test_helper.exs`.
- Required runtime env vars include `POSTGRES_DB_*`, `AMQP_URL`, `BASE_DOMAIN`, `LOG_LEVEL`, `METRICS_NAMESPACE`, `SENTRY_DSN`, `SENTRY_ENV`, `TZDATA_DATA_DIRECTORY`, `MIGRATIONS_PATH`, and internal API URLs like `INTERNAL_API_URL_*` (prod). See: `config/runtime.exs`.
- Runtime flags: `START_PUBLIC_API` and `START_INTERNAL_API` control which gRPC services start. See: `lib/notifications/application.ex`.
- Secrets source: webhook signing secret is read from Secrethub (secret env var `WEBHOOK_SECRET`). See: `lib/notifications/workers/webhook/secret.ex`.

## Infrastructure & Deployment (as implemented here)
- Docker: multi-stage build creates a Mix release and runs `bin/notifications start` in the runner image. See: `Dockerfile`.
- Local stack: docker compose runs `app`, `db` (Postgres 9.6), and `rabbitmq`. See: `docker-compose.yml`.
- Helm: Kubernetes chart and values live under `helm/`. See: `helm/Chart.yaml`, `helm/values.yaml`.
- Proto generation uses Dockerized `protoc` and external API repos; invoked by `make pb.gen`. See: `Makefile`, `scripts/internal_protos.sh`, `scripts/public_protos.sh`.

## Testing Strategy (as implemented here)
- Test layout: ExUnit tests under `test/notifications` with shared helpers under `test/support`. See: `test/notifications`, `test/support`.
- Test setup: gRPC mocks are started in `test/test_helper.exs`; Repo uses SQL sandbox mode. See: `test/test_helper.exs`, `config/test.exs`.
- Reporting: JUnit formatter is configured to write reports to `./out`. See: `config/test.exs`.
- How to run: `make test.ex` is wired via `Makefile` (which includes `../Makefile` for the actual target); exact command definition is outside this folder. Unknown / verify. See: `Makefile`.

## Observability
- Logging: Logger format/metadata are defined in config, and log level comes from `LOG_LEVEL`. See: `config/config.exs`, `config/runtime.exs`.
- Metrics: Watchman/StatsD is configured with a `notifications.<namespace>` prefix and used in workers. See: `config/runtime.exs`, `lib/notifications/workers/coordinator.ex`, `lib/notifications/workers/webhook.ex`, `lib/notifications/workers/slack.ex`.
- Error tracking: Sentry is configured in runtime and enabled via Logger backend outside dev/test; gRPC handlers use `Sentry.Grpc`. See: `config/runtime.exs`, `lib/notifications/application.ex`, `lib/notifications/api/public_api.ex`, `lib/notifications/api/internal_api.ex`.
- AMQP logging noise reduction: Lager error_logger_redirect is disabled. See: `config/_silent_lager.exs`.

## "How to Extend" Playbooks
- Add a new gRPC endpoint (public or internal): 1) Update proto definitions in the source repos and regenerate stubs with `make pb.gen` (proto sources live outside this folder; Unknown / verify). 2) Add a handler in `lib/notifications/api/public_api.ex` or `lib/notifications/api/internal_api.ex` plus a `run` module under the matching folder. 3) Update serialization/validation as needed. 4) Add tests under `test/notifications/api/...`. See: `Makefile`, `scripts/public_protos.sh`, `scripts/internal_protos.sh`, `lib/notifications/api/public_api.ex`, `lib/notifications/api/internal_api.ex`, `lib/notifications/api/*/serialization.ex`, `lib/notifications/util/validator.ex`, `test/notifications/api`.
- Add a new background job/AMQP consumer: 1) Create a worker using `Tackle.Consumer` like `Notifications.Workers.Coordinator` or `Notifications.Workers.Destroyer`. 2) Add it to the supervision tree in `Notifications.Application`. 3) Use Watchman metrics and Logger for observability. See: `lib/notifications/workers/coordinator.ex`, `lib/notifications/workers/destroyer.ex`, `lib/notifications/application.ex`.
- Add a new DB table/migration: 1) Add a migration under `priv/repo/migrations`. 2) Create or update an Ecto schema in `lib/notifications/models`. 3) Update any persistence helpers and filters that need the new data (for example, `RuleFactory`/`Coordinator.Filter`). See: `priv/repo/migrations`, `lib/notifications/models`, `lib/notifications/util/rule_factory.ex`, `lib/notifications/workers/coordinator/filter.ex`.
- Add a new config option: 1) Decide whether it is compile-time (`config/config.exs`) or runtime (`config/runtime.exs`). 2) Read it with `Application.get_env/2` or `Application.fetch_env!/2` in code. 3) Add defaults for local dev in `docker-compose.yml` if needed. See: `config/config.exs`, `config/runtime.exs`, `docker-compose.yml`.

## Appendix: Index of Important Files
- `README.md` - service summary and pointers to specs/architecture.
- `docs/specs.md` - notification use cases and requirements.
- `docs/arch.md` - architecture overview and components.
- `mix.exs` - dependencies and Elixir version.
- `config/config.exs` and `config/runtime.exs` - base and runtime configuration.
- `lib/notifications/application.ex` - OTP application entrypoint and supervision.
- `lib/notifications/api/public_api.ex` and `lib/notifications/api/internal_api.ex` - gRPC service entrypoints.
- `lib/notifications/workers/coordinator.ex` and `lib/notifications/workers/destroyer.ex` - AMQP consumers.
- `lib/notifications/workers/slack.ex` and `lib/notifications/workers/webhook.ex` - delivery workers.
- `lib/notifications/models/*` and `priv/repo/migrations/*` - data model and migrations.
- `Dockerfile`, `docker-compose.yml`, `helm/Chart.yaml` - deployment artifacts.
- `test/test_helper.exs` and `test/notifications/*` - test setup and suites.
