import Config

if System.get_env("TZDATA_DATA_DIRECTORY") != nil do
  config :tzdata, :data_dir, System.get_env("TZDATA_DATA_DIRECTORY")
else
  config :tzdata, :autoupdate, :disabled
end

config :logger, level: (System.get_env("LOG_LEVEL") || "info") |> String.to_atom()

config :watchman,
  host: "0.0.0.0",
  port: 8125,
  prefix: "notifications.#{System.get_env("METRICS_NAMESPACE") || "dev"}"

config :notifications, Notifications.Repo,
  adapter: Ecto.Adapters.Postgres,
  prepare: :unnamed,
  database: System.get_env("POSTGRES_DB_NAME") || "notifications",
  username: System.get_env("POSTGRES_DB_USER") || "postgres",
  password: System.get_env("POSTGRES_DB_PASSWORD") || "the-cake-is-a-lie",
  hostname: System.get_env("POSTGRES_DB_HOST") || "127.0.0.1",
  pool_size: String.to_integer(System.get_env("POSTGRES_DB_POOL_SIZE") || "1"),
  parameters: [application_name: "notifications"],
  ssl: System.get_env("POSTGRES_DB_SSL") == "true" || false

config :notifications, amqp_url: System.get_env("AMQP_URL") || "amqp://127.0.0.1:5672"

config :notifications, domain: System.get_env("BASE_DOMAIN") || if config_env() == :test, do: "testing.com", else: "semaphoreci.com"

config :sentry,
  dsn: System.get_env("SENTRY_DSN"),
  included_environments:
    ~w(prod pre-prod),
  environment_name: System.get_env("SENTRY_ENV") || "development",
  tags: %{
    application: "notifications"
  },
  enable_source_code_context: true,
  root_source_code_paths: [File.cwd!()],
  context_lines: 5

config :notifications, :migrations_path, System.get_env("MIGRATIONS_PATH") || "/app/priv/repo/migrations"

if config_env() == :prod do
  config :notifications, rbac_endpoint: System.fetch_env!("INTERNAL_API_URL_RBAC")
  config :notifications, repo_proxy_endpoint: System.fetch_env!("INTERNAL_API_URL_REPO_PROXY")
  config :notifications, projecthub_endpoint: System.fetch_env!("INTERNAL_API_URL_PROJECT")
  config :notifications, pipeline_endpoint: System.fetch_env!("INTERNAL_API_URL_PLUMBER")
  config :notifications, workflow_endpoint: System.fetch_env!("INTERNAL_API_URL_PLUMBER")
  config :notifications, organization_endpoint: System.fetch_env!("INTERNAL_API_URL_ORGANIZATION")
  config :notifications, secrethub_endpoint: System.fetch_env!("INTERNAL_API_URL_SECRETHUB") # sobelow_skip ["Config.Secrets"]
end
