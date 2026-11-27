import Config

config :scouter, Scouter.Repo,
  prepare: :unnamed,
  database: System.get_env("POSTGRES_DB_NAME"),
  username: System.get_env("POSTGRES_DB_USER"),
  password: System.get_env("POSTGRES_DB_PASSWORD"),
  hostname: System.get_env("POSTGRES_DB_HOST", "0.0.0.0"),
  pool_size: String.to_integer(System.get_env("POSTGRES_DB_POOL_SIZE", "1")),
  ssl: System.get_env("POSTGRES_DB_SSL", "false") == "true",
  ssl_opts: [verify: :verify_none]

config :watchman, prefix: "scouter.#{System.get_env("METRICS_NAMESPACE", "dev")}"

config :scouter, :migrations_path, System.get_env("MIGRATIONS_PATH", "/app/migrations")
