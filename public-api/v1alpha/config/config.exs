# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
import Config

config :pipelines_api, :enviroment, config_env()

# Solves dropping of log messages
config :lager, error_logger_hwm: 200
config :lager, async_threshold: 500
config :lager, async_threshold_window: 250

config :pipelines_api, grpc_timeout: 30_000
config :pipelines_api, wormhole_timeout: 30_500

config :grpc, http2_client_adapter: GRPC.Adapter.Gun

config :watchman,
  host: "localhost",
  port: 8125,
  prefix: "ppl-api.env-missing"

config :pipelines_api,
       :feature_api_endpoint,
       System.get_env("FEATURE_GRPC_URL") || "localhost:50051"

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

# This configuration is loaded before any dependency and is restricted
# to this project. If another project depends on this project, this
# file won't be loaded nor affect the parent project. For this reason,
# if you want to provide default values for your application for
# 3rd-party users, it should be done in your "mix.exs" file.

# You can configure your application as:
#
#     config :pipelines_api, key: :value
#
# and access this configuration in your application as:
#
#     Application.get_env(:pipelines_api, :key)
#
# You can also configure a 3rd-party app:
#
#     config :logger, level: :info
#

# It is also possible to import configuration files, relative to this
# directory. For example, you can emulate configuration per environment
# by uncommenting the line below and defining dev.exs, test.exs and such.
# Configuration from the imported file will override the ones defined
# here (which is why it is important to import them last).
#
import_config "#{config_env()}.exs"
