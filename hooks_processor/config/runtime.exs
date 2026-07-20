import Config

config :hooks_processor,
  repository_grpc_url: System.get_env("INTERNAL_API_URL_REPOSITORY"),
  projecthub_grpc_url: System.get_env("INTERNAL_API_URL_PROJECT"),
  plumber_grpc_url: System.get_env("INTERNAL_API_URL_PLUMBER"),
  user_api_grpc_url: System.get_env("INTERNAL_API_URL_USER"),
  branch_api_grpc_url: System.get_env("INTERNAL_API_URL_BRANCH")

config :hooks_processor,
  webhook_provider: System.get_env("WEBHOOK_PROVIDER"),
  amqp_url: System.get_env("AMQP_URL")

config :hooks_processor, HooksProcessor.EctoRepo,
  prepare: :unnamed,
  database: System.get_env("POSTGRES_DB_NAME"),
  username: System.get_env("POSTGRES_DB_USER"),
  password: System.get_env("POSTGRES_DB_PASSWORD"),
  hostname: System.get_env("POSTGRES_DB_HOST"),
  pool_size: String.to_integer(System.get_env("POSTGRES_DB_POOL_SIZE") || "1"),
  ssl: System.get_env("POSTGRES_DB_SSL") == "true" || false,
  ssl_opts: [
    verify: :verify_none
  ]

config :logger, level: (System.get_env("LOG_LEVEL") || "info") |> String.to_atom()

if config_env() == :prod do
  config :logger, :default_handler, formatter: LoggerJSON.Formatters.Basic.new()
end

# We need valid dsn or nil
sentry_dsn = System.get_env("SENTRY_DSN", "") |> String.trim() |> (&if(&1 != "", do: &1, else: nil)).()

config :sentry,
  dsn: sentry_dsn,
  tags: %{
    application: System.get_env("SENTRY_APPLICATION")
  },
  environment_name: System.get_env("SENTRY_ENV")
