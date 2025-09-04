import Config

config :ephemeral_environments, EphemeralEnvironments.Repo,
  database: System.fetch_env!("POSTGRES_DB_NAME"),
  username: System.fetch_env!("POSTGRES_DB_USER"),
  password: System.fetch_env!("POSTGRES_DB_PASSWORD"),
  hostname: System.fetch_env!("POSTGRES_DB_HOST"),
  pool_size: String.to_integer(System.fetch_env!("POSTGRES_DB_POOL_SIZE")),
  ssl: System.fetch_env!("POSTGRES_DB_SSL") == "true",
  ssl_opts: [verify: :verify_none]

config :watchman,
  host: System.fetch_env!("METRICS_SIDECAR_ADDRESS"),
  port: String.to_integer(System.fetch_env!("METRICS_SIDECAR_PORT")),
  prefix: "ephemeral_environments.#{System.fetch_env!("METRICS_NAMESPACE")}"

config :ephemeral_environments,
       :migrations_path,
       System.get_env("MIGRATIONS_PATH", "/app/migrations")
