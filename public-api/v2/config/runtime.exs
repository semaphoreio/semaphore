import Config

if System.get_env("TZDATA_DATA_DIRECTORY") != nil do
  config :tzdata, :data_dir, System.get_env("TZDATA_DATA_DIRECTORY")
else
  config :tzdata, :autoupdate, :disabled
end

config :watchman,
  host: "0.0.0.0",
  port: 8125,
  prefix: "public_api_v1.#{System.get_env("METRICS_NAMESPACE") || "dev"}"

config :public_api, amqp_url: System.get_env("AMQP_URL") || "amqp://rabbitmq:5672"

config :logger, level: (System.get_env("LOG_LEVEL") || "info") |> String.to_atom()

config :public_api,
  cache_prefix: System.get_env("CACHE_PREFIX") || "public_api/",
  cache_host: System.get_env("CACHE_HOST") || "localhost",
  cache_port: elem(Integer.parse(System.get_env("CACHE_PORT") || "6379"), 0),
  cache_pool_size: elem(Integer.parse(System.get_env("CACHE_POOL_SIZE") || "5"), 0),
  cache_timeout: elem(Integer.parse(System.get_env("CACHE_TIMEOUT") || "900000"), 0),
  use_rbac_api: if(System.get_env("USE_RBAC_API") == "true", do: true, else: false)

config :public_api,
  permission_patrol_grpc_endpoint: System.get_env("PP_GRPC_URL") || "127.0.0.1:50052",
  pipeline_api_grpc_endpoint: System.get_env("PPL_GRPC_URL") || "127.0.0.1:50052",
  workflow_api_grpc_endpoint: System.get_env("WF_GRPC_URL") || "127.0.0.1:50052",
  rbac_api_grpc_endpoint: System.get_env("INTERNAL_API_URL_RBAC") || "127.0.0.1:50052",
  feature_grpc_endpoint: System.get_env("FEATURE_GRPC_URL") || "127.0.0.1:50052",
  gofer_grpc_endpoint: System.get_env("GOFER_GRPC_URL") || "127.0.0.1:50052",
  secrethub_grpc_endpoint: System.get_env("SECRETHUB_GRPC_URL") || "127.0.0.1:50052",
  dashboardhub_grpc_endpoint: System.get_env("DASHBOARDHUB_GRPC_URL") || "127.0.0.1:50052",
  canvas_grpc_endpoint: System.get_env("INTERNAL_API_URL_CANVAS") || "127.0.0.1:50052",
  self_hosted_hub_grpc_endpoint: System.get_env("SELF_HOSTED_HUB_URL") || "127.0.0.1:50052",
  notifications_grpc_endpoint: System.get_env("NOTIFICATIONS_GRPC_URL") || "127.0.0.1:50052",
  projecthub_grpc_endpoint: System.get_env("PROJECTHUB_GRPC_URL") || "127.0.0.1:50052"
