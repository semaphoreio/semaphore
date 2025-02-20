import Config

config :logger, level: (System.get_env("LOG_LEVEL") || "debug") |> String.to_atom()

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:user_id]

config :watchman,
  host: "0.0.0.0",
  port: 8125,
  prefix: "rbac-ce.#{System.get_env("METRICS_NAMESPACE") || "dev"}"

config :rbac, Rbac.Repo,
  adapter: Ecto.Adapters.Postgres,
  database: System.get_env("POSTGRES_DB_NAME") || "rbac_ce",
  username: System.get_env("POSTGRES_DB_USER") || "postgres",
  password: System.get_env("POSTGRES_DB_PASSWORD") || "the-cake-is-a-lie",
  hostname: System.get_env("POSTGRES_DB_HOST") || "127.0.0.1",
  pool_size: String.to_integer(System.get_env("POSTGRES_DB_POOL_SIZE") || "1"),
  parameters: [application_name: "rbac"],
  migration_primary_key: [name: :id, type: :binary_id],
  ssl: System.get_env("POSTGRES_DB_SSL") == "true" || false,
  migration_timestamps: [
    type: :naive_datetime,
    inserted_at: :created_at,
    updated_at: :updated_at
  ]

config :rbac, ecto_repos: [Rbac.Repo]

import_config "#{config_env()}.exs"
