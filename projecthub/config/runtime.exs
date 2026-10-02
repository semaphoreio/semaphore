import Config

if System.get_env("TZDATA_DATA_DIRECTORY") != nil do
  config :tzdata, :data_dir, System.get_env("TZDATA_DATA_DIRECTORY")
else
  config :tzdata, :autoupdate, :disabled
end

config :logger, level: (System.get_env("LOG_LEVEL") || "info") |> String.to_atom()

config :projecthub, Projecthub.Repo,
  prepare: :unnamed,
  database: System.get_env("POSTGRES_DB_NAME") || "projecthub",
  username: System.get_env("POSTGRES_DB_USER") || "postgres",
  password: System.get_env("POSTGRES_DB_PASSWORD") || "the-cake-is-a-lie",
  hostname: System.get_env("POSTGRES_DB_HOST") || "127.0.0.1",
  pool_size: String.to_integer(System.get_env("POSTGRES_DB_POOL_SIZE") || "1"),
  ssl: System.get_env("POSTGRES_DB_SSL") == "true" || false

config :projecthub, amqp_url: System.get_env("AMQP_URL") || "amqp://127.0.0.1:5672"

config :watchman,
  host: "0.0.0.0",
  port: 8125,
  prefix: "projecthub.#{System.get_env("METRICS_NAMESPACE") || "dev"}"

config :sentry,
  dsn: System.get_env("SENTRY_DSN"),
  included_environments: ~w(prod pre-prod),
  environment_name: System.get_env("SENTRY_ENV") || "development",
  enable_source_code_context: true,
  root_source_code_paths: [File.cwd!()],
  tags: %{
    application: "projecthub"
  },
  context_lines: 5

config :projecthub,
  start_project_init_worker?: System.get_env("START_PROJECT_INIT_WORKER"),
  start_project_cleaner?: System.get_env("START_PROJECT_CLEANER"),
  start_internal_api?: System.get_env("START_INTERNAL_API")

feature_provider =
  System.get_env("FEATURE_YAML_PATH")
  |> case do
    nil ->
      {Projecthub.FeatureHubProvider,
       [
         cache: {FeatureProvider.CachexCache, name: :feature_provider_cache, ttl_ms: :timer.minutes(10)}
       ]}

    path ->
      {FeatureProvider.YamlProvider, [yaml_path: path, agent_name: :feature_provider_agent]}
  end

config :projecthub, :feature_provider, feature_provider

if config_env() == :prod do
  config :projecthub,
    artifacthub_grpc_endpoint: System.fetch_env!("INTERNAL_API_URL_ARTIFACTHUB"),
    cache_grpc_endpoint: System.fetch_env!("INTERNAL_API_URL_CACHEHUB"),
    feature_grpc_endpoint: System.fetch_env!("INTERNAL_API_URL_FEATURE"),
    rbac_grpc_endpoint: System.fetch_env!("INTERNAL_API_URL_RBAC"),
    organization_grpc_endpoint: System.fetch_env!("INTERNAL_API_URL_ORGANIZATION"),
    periodic_scheduler_grpc_endpoint: System.fetch_env!("INTERNAL_API_URL_SCHEDULER"),
    repo_proxy_grpc_endpoint: System.fetch_env!("INTERNAL_API_URL_REPO_PROXY"),
    repohub_grpc_endpoint: System.fetch_env!("INTERNAL_API_URL_REPOHUB"),
    repositoryhub_grpc_endpoint: System.fetch_env!("INTERNAL_API_URL_REPOSITORY"),
    user_grpc_endpoint: System.fetch_env!("INTERNAL_API_URL_USER")
end
