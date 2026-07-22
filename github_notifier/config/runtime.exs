import Config


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
    System.get_env("METRICS_PREFIX") || "github_notifier.#{System.get_env("METRICS_NAMESPACE") || "dev"}"

config :logger, level: String.to_atom(System.get_env("LOG_LEVEL") || "info")

config :sentry,
  dsn: System.get_env("SENTRY_DSN"),
  environment_name: System.get_env("SENTRY_ENV") || "development",
  enable_source_code_context: true,
  root_source_code_path: File.cwd!(),
  included_environments: [:prod],
  tags: %{
    env: System.get_env("K8S_NAMESPACE") || "dev",
    logger: System.get_env("K8S_DEPLOYMENT_NAME"),
    application: "github_notifier"
  }

config :github_notifier, host: System.get_env("BASE_DOMAIN") || "semaphoreci.local"
config :github_notifier, amqp_url: System.get_env("AMQP_URL") || "amqp://localhost:5672"

config :github_notifier,
  context_prefix: System.get_env("CONTEXT_PREFIX") || "ci/semaphoreci"

if config_env() == :prod do
  config :github_notifier,
    pipeline_grpc_endpoint: System.fetch_env!("INTERNAL_API_URL_PLUMBER"),
    projecthub_grpc_endpoint: System.fetch_env!("INTERNAL_API_URL_PROJECT"),
    organization_grpc_endpoint: System.fetch_env!("INTERNAL_API_URL_ORGANIZATION"),
    hook_api_grpc_endpoint: System.fetch_env!("INTERNAL_API_URL_REPO_PROXY"),
    repositoryhub_api_grpc_endpoint: System.fetch_env!("INTERNAL_API_URL_REPOSITORY"),
    velocityhub_api_grpc_endpoint: System.fetch_env!("INTERNAL_API_URL_VELOCITY"),
    feature_grpc_endpoint: System.fetch_env!("INTERNAL_API_URL_FEATURE")
end

feature_provider =
  System.get_env("FEATURE_YAML_PATH")
  |> case do
    nil ->
      {GithubNotifier.FeatureHubProvider,
       [
         cache: {FeatureProvider.CachexCache, name: :feature_provider_cache, ttl_ms: :timer.minutes(10)}
       ]}

    path ->
      {FeatureProvider.YamlProvider, [yaml_path: path, agent_name: :feature_provider_agent]}
  end

config FeatureProvider, :provider, feature_provider
