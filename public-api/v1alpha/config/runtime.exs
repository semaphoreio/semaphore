import Config

config :logger, level: (System.get_env("LOG_LEVEL") || "info") |> String.to_atom()

# Do not print empty line between log events.
config :logger, :console, format: "$time $metadata[$level] $levelpad$message\n"

config :pipelines_api,
       :feature_api_endpoint,
       System.get_env("FEATURE_GRPC_URL") || "feature-hub:50052"

on_prem? = if(System.get_env("ON_PREM") == "true", do: true, else: false)
config :pipelines_api, on_prem?: on_prem?

feature_provider =
  if on_prem? do
    {FeatureProvider.YamlProvider,
     [
       yaml_path: System.get_env("FEATURE_YAML_PATH") || "/app/features.yml",
       agent_name: :feature_provider_pipelines_api_agent
     ]}
  else
    {PipelinesAPI.FeatureHubProvider,
     [
       cache:
         {FeatureProvider.CachexCache, name: :feature_provider_cache, ttl_ms: :timer.hours(6)}
     ]}
  end

config :pipelines_api, feature_provider: feature_provider
