import Config

config :logger, level: (System.get_env("LOG_LEVEL") || "info") |> String.to_atom()

config :branch_hub, BranchHub.Repo,
  adapter: Ecto.Adapters.Postgres,
  prepare: :unnamed,
  database: System.get_env("POSTGRES_DB_NAME") || "front",
  username: System.get_env("POSTGRES_DB_USER") || "postgres",
  password: System.get_env("POSTGRES_DB_PASSWORD") || "the-cake-is-a-lie",
  hostname: System.get_env("POSTGRES_DB_HOST") || "127.0.0.1",
  pool_size: String.to_integer(System.get_env("POSTGRES_DB_POOL_SIZE") || "1"),
  parameters: [application_name: "branch_hub"],
  ssl: System.get_env("POSTGRES_DB_SSL") == "true" || false

config :watchman,
  host: "0.0.0.0",
  port: 8125,
  prefix: "branch_hub.#{System.get_env("METRICS_NAMESPACE") || "dev"}"

config :sentry,
  dsn: System.get_env("SENTRY_DSN"),
  included_environments: ~w(prod pre-prod),
  environment_name: System.get_env("SENTRY_ENV") || "development",
  enable_source_code_context: true,
  root_source_code_paths: [File.cwd!()],
  context_lines: 5
