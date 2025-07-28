import Config

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:user_id]

config :watchman,
  host: "0.0.0.0",
  port: 8125,
  prefix: "rbac-ee.#{System.get_env("METRICS_NAMESPACE") || "dev"}"

config :rbac, :migrations_path, "/app/repo/migrations"

config :rbac, Rbac.Repo,
  adapter: Ecto.Adapters.Postgres,
  database: System.get_env("POSTGRES_DB_NAME") || "guard",
  username: System.get_env("POSTGRES_DB_USER") || "postgres",
  password: System.get_env("POSTGRES_DB_PASSWORD") || "the-cake-is-a-lie",
  hostname: System.get_env("POSTGRES_DB_HOST") || "127.0.0.1",
  pool_size: String.to_integer(System.get_env("POSTGRES_DB_POOL_SIZE") || "1"),
  parameters: [application_name: "rbac"],
  migration_primary_key: [name: :id, type: :binary_id],
  ssl: System.get_env("POSTGRES_DB_SSL") == "true" || false,
  ssl_opts: [verify: :verify_none],
  migration_timestamps: [
    type: :naive_datetime,
    inserted_at: :inserted_at,
    updated_at: :updated_at
  ]

config :rbac, Rbac.FrontRepo,
  adapter: Ecto.Adapters.Postgres,
  database: System.get_env("POSTGRES_FRONT_DB_NAME") || "front",
  username: System.get_env("POSTGRES_DB_USER") || "postgres",
  password: System.get_env("POSTGRES_DB_PASSWORD") || "the-cake-is-a-lie",
  hostname: System.get_env("POSTGRES_DB_HOST") || "127.0.0.1",
  pool_size: String.to_integer(System.get_env("POSTGRES_DB_POOL_SIZE") || "1"),
  parameters: [application_name: "guard"],
  ssl: System.get_env("POSTGRES_DB_SSL") == "true" || false,
  ssl_opts: [verify: :verify_none]

config :rbac, ecto_repos: [Rbac.Repo, Rbac.FrontRepo]

config :rbac,
  key_value_store_backend: Rbac.Store.Postgres,
  user_permissions_store_name: "UserPermissionsKeyValueStore",
  project_access_store_name: "ProjectAccessKeyValueStore"

config :rbac,
  projecthub_grpc_endpoint: "127.0.0.1:50052",
  repositoryhub_grpc_endpoint: "127.0.0.1:50052",
  organization_grpc_endpoint: "127.0.0.1:50052"

config :rbac, amqp_url: System.get_env("AMQP_URL") || "amqp://127.0.0.1:5672"

if System.get_env("AMQP_URL") != nil do
  config :amqp,
    connections: [
      amqp: [url: System.get_env("AMQP_URL")]
    ],
    channels: [
      audit: [connection: :amqp],
      authorization: [connection: :amqp],
      user: [connection: :amqp]
    ]
end

config :rbac,
  oidc: [
    discovery_url: System.get_env("OIDC_DISCOVERY_URL"),
    client_id: System.get_env("OIDC_CLIENT_ID"),
    client_secret: System.get_env("OIDC_CLIENT_SECRET"),
    manage_url: System.get_env("OIDC_MANAGE_URL"),
    manage_client_id: System.get_env("OIDC_MANAGE_CLIENT_ID"),
    manage_client_secret: System.get_env("OIDC_MANAGE_CLIENT_SECRET")
  ]

config :rbac, base_domain: System.get_env("BASE_DOMAIN")
config :rbac, session_secret_key_base: System.get_env("SESSION_SECRET_KEY_BASE")
config :rbac, session_key: System.get_env("SESSION_COOKIE_NAME")

import_config "#{config_env()}.exs"
