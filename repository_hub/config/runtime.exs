import Config

if System.get_env("TZDATA_DATA_DIRECTORY") != nil do
  config :tzdata, :data_dir, System.get_env("TZDATA_DATA_DIRECTORY")
else
  config :tzdata, :autoupdate, :disabled
end

config :repository_hub, amqp_url: System.get_env("AMQP_URL") || "amqp://127.0.0.1:5672"

if config_env() == :prod do
  config :watchman,
    prefix: "repository_hub.#{System.get_env("METRICS_NAMESPACE") || "dev"}"

  config :repository_hub, RepositoryHub.Repo,
    prepare: :unnamed,
    database: System.get_env("POSTGRES_DB_NAME"),
    username: System.get_env("POSTGRES_DB_USER"),
    password: System.get_env("POSTGRES_DB_PASSWORD"),
    hostname: System.get_env("POSTGRES_DB_HOST"),
    parameters: [application_name: "repository-hub"],
    pool_size: String.to_integer(System.get_env("POSTGRES_DB_POOL_SIZE") || "1"),
    ssl: System.get_env("POSTGRES_DB_SSL") == "true" || false,
    ssl_opts: [verify: :verify_none]

  config :repository_hub,
    projecthub_grpc_server: System.get_env("PROJECTHUB_GRPC_URL"),
    user_grpc_server: System.get_env("USER_GRPC_URL"),
    repository_integrator_grpc_server: System.get_env("REPOSITORY_INTEGRATOR_GRPC_URL"),
    organization_grpc_endpoint: System.get_env("ORGANIZATION_GRPC_URL"),
    webhook_host: System.get_env("HOOKS_HOST") || "example.com/hooks"

  log_level =
    System.get_env("LOG_LEVEL", "info")
    |> String.downcase()
    |> String.trim()
    |> case do
      "debug" -> :debug
      "warning" -> :warning
      _ -> :info
    end

  config :logger,
    level: log_level

  config :sentry,
    dsn: System.get_env("SENTRY_DSN"),
    environment_name: System.get_env("SENTRY_ENV") || "development"

  config :repository_hub, RepositoryHub.DeployKeyEncryptor,
    module: {RepositoryHub.GRPCEncryptor, url: System.get_env("ENCRYPTOR_URL")}

  config :repository_hub, RepositoryHub.WebhookSecretEncryptor,
    module: {RepositoryHub.GRPCEncryptor, url: System.get_env("ENCRYPTOR_URL")}

  config :repository_hub, RepositoryHub.RemoteIdSyncWorker,
    enabled: System.get_env("REMOTE_ID_SYNC_ENABLED") != "false",
    rate_limit_per_minute: String.to_integer(System.get_env("REMOTE_ID_SYNC_RATE_LIMIT_PER_MINUTE") || "10")
end

on_prem? = if(System.get_env("ON_PREM") == "true", do: true, else: false)
config :repository_hub, :on_prem?, on_prem?
