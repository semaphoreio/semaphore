# Internal Architecture Notes

## What This Service Does
`secrethub` is the semaphore secrets service. It stores encrypted organization, project, and deployment secrets in Postgres, exposes internal gRPC APIs used by other backend services, serves a public gRPC API for agents/CLI, and hosts an OpenID Connect (OIDC) HTTP endpoint that issues scoped JWTs for third parties. Secrets are always persisted encrypted-at-rest and decrypted on demand through the external encryptor service.

## Runtime Topology
- Entry point: `Secrethub.Application` boots the supervision tree, initialises the feature provider, and conditionally starts gRPC servers, OIDC HTTP, the OpenID key manager, and AMQP consumers based on `START_*` env vars.
- Persistence: `Secrethub.Repo` wraps Postgres via Ecto; migrations live in `priv/repo/migrations`.
- Caches: Cachex stores RBAC permission checks (`:auth_cache`), feature flags, and OIDC usage counters; eviction windows are configured in `application.ex`.
- GRPC servers: `Secrethub.InternalGrpcApi`, `Secrethub.PublicGrpcApi`, and `Secrethub.ProjectSecretsPublicApi` run under `GRPC.Server.Supervisor`. Health checks use `GrpcHealthCheck.Server`.
- OpenID Connect: `lib/secrethub/open_id_connect/**` hosts a Plug stack served by Cowboy plus a `KeyManager` GenServer that persists rotating signing keys under `priv/openid_keys_in_tests` for local runs.

## Module Map
- Core domain: `lib/secrethub/secret.ex` holds the main Ecto schema and CRUD logic; `project_secrets/**` contains a parallel flow for project-scoped secrets, while `deployment_targets/**` manages deploy target secrets.
- Security helpers: `Secrethub.Auth` talks to the RBAC gRPC service with Cachex-backed memoization; `Secrethub.Encryptor` wraps the external encryptor gRPC API.
- Integrations: `FeatureHubProvider` queries the feature service; `ProjecthubClient` fetches project metadata; `OwnerDeletedConsumer` listens for AMQP deletion events to clean up secrets.
- Utilities: `model/**` defines plain structs used during (de)serialization; `level_gen/**` provides helpers for assembling multi-level env/file payloads; `utils.ex` is a catch-all map transformer used by the gRPC APIs.
- Generated stubs: `lib/internal_api/**` and `lib/public_api/**` are regenerated from the repos referenced in the `Makefile` (`make pb.gen.*`).

## Data Model Highlights
- `secrets` table stores `content_encrypted`; the decrypted `content` map is virtual and shaped via `Secrethub.Model.Content` with nested `EnvVar` and `File`.
- Project secrets use a separate schema (`project_secrets/secret.ex`) with feature-flag-aware visibility filtering driven by `FeatureProvider`.
- Secret policies include metadata such as `org_config`, `all_projects`, `project_ids`, and audit fields (`created_by`, `used_by`). Access checks combine RBAC results with feature flags before persisting changes.

## External Services & Configuration
- gRPC endpoints are configured in `config/*.exs`: `:encryptor`, `:feature_api_endpoint`, `:rbac_grpc_endpoint`, `:projecthub_grpc_endpoint`.
- AMQP connection details, Postgres credentials, and service ports are defined in the repo Makefile and surfaced as environment variables (`POSTGRES_DB_*`, `AMQP_URL`, `BASE_DOMAIN`, `START_*` flags).
- Feature flags can be bootstrapped locally by setting `FEATURE_YAML_PATH`, which attaches the configured provider to the supervision tree.

## Build & Local Development
- Core commands: `mix deps.get`, `mix compile`, `mix test`, `mix credo --strict`.
- Integration flows (DB/protos) rely on Docker: `make test.ex.setup` provisions Postgres/RabbitMQ, runs migrations, and seeds data; `make pb.gen.internal` / `make pb.gen.public` clone the internal API repos and regenerate proto stubs (requires GitHub access and Docker).
- OpenID HTTP port and gRPC ports are read from config (`config/dev.exs`); adjust if ports clash with other services.

## Testing Aids
- ExUnit helpers live in `test/support`: `DataCase` bootstraps the DB sandbox, `Factories` build fixture structs, and `FakeServices` starts in-process gRPC mocks when `start_stub_grpc_services?/0` evaluates to true (dev/test envs).
- Tests commonly assert on decrypted payloads using `Secrethub.Encryptor.decrypt_secret/1`; prefer the factory helpers to avoid manual encryption.
- CI uses `JUnitFormatter` (configured in `mix.exs`) and expects `mix test` and `mix credo` to pass before merging.

## Observability & Troubleshooting
- Logging: Sentry backend is registered in `Application.start/2`; ensure SENTRY_DSN is present in non-local envs.
- Metrics: Watchman timings gauge gRPC calls, encryption latency, and feature fetch success/failure (`watchman` client).
- Feature cache invalidation: `FeatureProviderInvalidatorWorker` monitors YAML-backed providers; ensure `FEATURE_YAML_PATH` is mounted in dev if you rely on live refresh.
- When debugging auth issues, inspect `:auth_cache` entries (Cachex) and verify RBAC gRPC connectivity; the cache keys are SHA-256 hashes of the payload.
