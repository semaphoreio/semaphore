import Config

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.
# The block below contains prod specific runtime configuration.

get_env! = &(System.get_env(&1) || raise("env variable #{&1} is missing"))
on_prem? = System.get_env("ON_PREM") == "true"
namespaces = ~w(METRICS_NAMESPACE K8S_NAMESPACE)

if config_env() == :prod do
  config :scheduler, Scheduler.PeriodicsRepo,
    prepare: :unnamed,
    hostname: get_env!.("DB_HOSTNAME"),
    username: get_env!.("DB_USERNAME"),
    password: get_env!.("DB_PASSWORD"),
    database: "periodics_repo",
    pool_size: String.to_integer(System.get_env("PERIODICS_DB_POOL_SIZE") || "2"),
    ssl: System.get_env("POSTGRES_DB_SSL") == "true"

  config :scheduler, Scheduler.FrontRepo,
    prepare: :unnamed,
    hostname: get_env!.("DB_HOSTNAME"),
    username: get_env!.("DB_USERNAME"),
    password: get_env!.("DB_PASSWORD"),
    database: "front",
    pool_size: String.to_integer(System.get_env("FRONT_DB_POOL_SIZE") || "2"),
    ssl: System.get_env("POSTGRES_DB_SSL") == "true"

  config :scheduler,
    rabbitmq_url: get_env!.("RABBITMQ_URL")

  config :watchman,
    host: System.get_env("METRICS_HOST") || "0.0.0.0",
    port: (System.get_env("METRICS_PORT") || "8125") |> String.to_integer(),
    send_only: if(on_prem?, do: :external, else: :internal),
    external_backend: if(on_prem?, do: :aws_cloudwatch, else: :statsd_graphite),
    prefix:
      System.get_env("METRICS_PREFIX") ||
        "periodic-sch.#{System.get_env("METRICS_NAMESPACE") || "env-missing"}"

  feature_provider =
    System.get_env("FEATURE_YAML_PATH")
    |> case do
      nil ->
        {Scheduler.FeatureHubProvider,
         [
           cache:
             {FeatureProvider.CachexCache,
              name: :feature_provider_cache, ttl_ms: :timer.minutes(10)}
         ]}

      path ->
        {FeatureProvider.YamlProvider, [yaml_path: path, agent_name: :feature_provider_agent]}
    end

  config :scheduler,
    feature_provider: feature_provider

  config :scheduler,
    workflow_api_grpc_endpoint: System.fetch_env!("INTERNAL_API_URL_PLUMBER"),
    repo_proxy_api_grpc_endpoint: System.fetch_env!("INTERNAL_API_URL_REPO_PROXY"),
    projecthub_api_grpc_endpoint: System.fetch_env!("INTERNAL_API_URL_PROJECT"),
    repositoryhub_grpc_endpoint: System.fetch_env!("INTERNAL_API_URL_REPOSITORY"),
    feature_api_grpc_endpoint: System.get_env("INTERNAL_API_URL_FEATURE")
end
