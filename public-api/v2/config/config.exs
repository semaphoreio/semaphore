# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
import Config

config :public_api, :environment, config_env()

config :public_api, grpc_timeout: 30_000

config :watchman,
  host: "localhost",
  port: 8125,
  prefix: "ppl-api.env-missing"

feature_provider =
  System.get_env("ON_PREM")
  |> case do
    "true" ->
      {FeatureProvider.YamlProvider,
       [
         yaml_path: System.get_env("FEATURE_YAML_PATH"),
         agent_name: :feature_provider_public_api_agent
       ]}

    _ ->
      {InternalClients.Feature,
       [
         cache:
           {FeatureProvider.CachexCache, name: :feature_provider_cache, ttl_ms: :timer.hours(6)}
       ]}
  end

config :public_api, feature_provider: feature_provider

import_config "#{config_env()}.exs"
