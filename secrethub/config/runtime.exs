import Config

if System.get_env("TZDATA_DATA_DIRECTORY") != nil do
  config :tzdata, :data_dir, System.get_env("TZDATA_DATA_DIRECTORY")
else
  config :tzdata, :autoupdate, :disabled
end

config :watchman,
  host: "0.0.0.0",
  port: 8125,
  prefix: "secrethub.#{System.get_env("METRICS_NAMESPACE") || "dev"}"

config :secrethub, amqp_url: System.get_env("AMQP_URL") || "amqp://rabbitmq:5672"

config :secrethub, Secrethub.Repo,
  adapter: Ecto.Adapters.Postgres,
  prepare: :unnamed,
  database: System.get_env("POSTGRES_DB_NAME") || "secrethub",
  username: System.get_env("POSTGRES_DB_USER") || "postgres",
  password: System.get_env("POSTGRES_DB_PASSWORD") || "the-cake-is-a-lie",
  hostname: System.get_env("POSTGRES_DB_HOST") || "127.0.0.1",
  pool_size: String.to_integer(System.get_env("POSTGRES_DB_POOL_SIZE") || "1"),
  parameters: [application_name: "secrethub"],
  loggers: [
    {Ecto.LogEntry, :log, [:debug]}
  ],
  migration_timestamps: [type: :naive_datetime_usec],
  ssl: System.get_env("POSTGRES_DB_SSL") == "true" || false

config :secrethub,
  rbac_grpc_endpoint: System.fetch_env!("INTERNAL_API_URL_RBAC") || "127.0.0.1:50051",
  feature_api_endpoint: System.fetch_env!("INTERNAL_API_URL_FEATURE") || "127.0.0.1:50051",
  projecthub_grpc_endpoint: System.fetch_env!("INTERNAL_API_URL_PROJECT") || "127.0.0.1:50051"

config :sentry,
  dsn: System.get_env("SENTRY_DSN"),
  environment_name: config_env(),
  tags: %{
    application: "secrethub"
  },
  included_environments: [:prod]

config :secrethub,
       :migrations_path,
       System.get_env("MIGRATIONS_PATH") || "/app/priv/repo/migrations"

on_prem? = System.get_env("ON_PREM") == "true"

config :secrethub, domain: System.get_env("BASE_DOMAIN")
config :secrethub, openid_keys_path: System.get_env("OPENID_KEYS_PATH")

if on_prem? do
  # in on-prem we cache the keys for 24 hours by default
  config :secrethub,
    openid_keys_cache_max_age_in_s:
      String.to_integer(System.get_env("OPENID_KEYS_CACHE_MAX_AGE_IN_S") || "86400")
end

config :secrethub, on_prem?: on_prem?

config :secrethub, Secrethub.KeyVault, keys_path: System.get_env("KEY_VAULT_PATH")
config :secrethub, Secrethub.Encryptor, url: System.get_env("ENCRYPTOR_URL")

feature_provider =
  System.get_env("FEATURE_YAML_PATH")
  |> case do
    nil -> {Secrethub.FeatureHubProvider, [
      cache: {FeatureProvider.CachexCache, name: :feature_cache, ttl_ms: :timer.minutes(10)}
    ]}
    path -> {FeatureProvider.YamlProvider, [yaml_path: path, agent_name: :feature_provider_agent]}
  end

config :secrethub, :feature_provider, feature_provider
