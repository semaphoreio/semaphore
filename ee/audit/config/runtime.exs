import Config

if System.get_env("TZDATA_DATA_DIRECTORY") != nil do
  config :tzdata, :data_dir, System.get_env("TZDATA_DATA_DIRECTORY")
else
  config :tzdata, :autoupdate, :disabled
end

{metric_channel, metrics_format} =
  System.get_env("ON_PREM")
  |> case do
    "true" -> {:external, :aws_cloudwatch}
    _ -> {:internal, :statsd_graphite}
  end

config :watchman,
  host: System.get_env("METRICS_HOST") || "0.0.0.0",
  port: (System.get_env("METRICS_PORT") || "8125") |> Integer.parse() |> elem(0),
  send_only: metric_channel,
  external_backend: metrics_format,
  prefix:
    System.get_env("METRICS_PREFIX") || "audit.#{System.get_env("METRICS_NAMESPACE") || "dev"}"

config :audit, Audit.Repo,
  adapter: Ecto.Adapters.Postgres,
  prepare: :unnamed,
  database: System.get_env("POSTGRES_DB_NAME") || "audit",
  username: System.get_env("POSTGRES_DB_USER") || "postgres",
  password: System.get_env("POSTGRES_DB_PASSWORD") || "the-cake-is-a-lie",
  hostname: System.get_env("POSTGRES_DB_HOST") || "127.0.0.1",
  parameters: [application_name: "audit"],
  pool_size: String.to_integer(System.get_env("POSTGRES_DB_POOL_SIZE") || "1"),
  ssl: System.get_env("POSTGRES_DB_SSL") == "true" || false,
  start_apps_before_migration: [:ssl]

config :audit, amqp_url: System.get_env("AMQP_URL") || "amqp://127.0.0.1:5672"

config :sentry,
  dsn: System.get_env("SENTRY_DSN"),
  environment_name: System.get_env("SENTRY_ENV") || "development",
  tags: %{
    application: "audit"
  },
  included_environments: [:prod]

config :audit, :migrations_path, System.get_env("MIGRATIONS_PATH") || "/app/priv/repo/migrations"

feature_provider =
  System.get_env("FEATURE_YAML_PATH")
  |> case do
    nil ->
      {
        Audit.FeatureHubProvider,
        [
          cache:
            {FeatureProvider.CachexCache,
             name: :feature_provider_cache, ttl_ms: :timer.minutes(10)}
        ]
      }

    path ->
      {FeatureProvider.YamlProvider, [yaml_path: path, agent_name: :feature_provider_agent]}
  end

config :audit, :feature_provider, feature_provider

if config_env() == :prod do
  config :audit, Audit.CredentialsEncryptor,
    module: {Audit.GrpcEncryptor, url: System.get_env("ENCRYPTOR_URL")}

  config :audit,
    user_grpc_endpoint: System.fetch_env!("INTERNAL_API_URL_USER"),
    feature_api_endpoint: System.fetch_env!("INTERNAL_API_URL_FEATURE")
else
  config :audit, Audit.CredentialsEncryptor, module: {Audit.FakeEncryptor, []}

  config :audit,
    user_grpc_endpoint: "127.0.0.1:50052",
    feature_api_endpoint: "127.0.0.1:50052"
end
