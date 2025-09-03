import Config

config :ephemeral_environments, EphemeralEnvironments.Repo,
  database: System.get_env("POSTGRES_DB_NAME", "ephemeral_environments"),
  username: System.get_env("POSTGRES_DB_USER", "postgres"),
  password: System.get_env("POSTGRES_DB_PASSWORD", "the-cake-is-a-lie"),
  hostname: System.get_env("POSTGRES_DB_HOST", "0.0.0.0"),
  pool_size: String.to_integer(System.get_env("POSTGRES_DB_POOL_SIZE", "1")),
  ssl: System.get_env("POSTGRES_DB_SSL", "false") == "true",
  ssl_opts: [verify: :verify_none]

config :watchman, prefix: "ephemeral_environments.#{System.get_env("METRICS_NAMESPACE", "dev")}"

config :ephemeral_environments,
       :migrations_path,
       System.get_env("MIGRATIONS_PATH", "/app/migrations")
