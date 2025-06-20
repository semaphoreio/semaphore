import Config

config :watchman,
  host: "0.0.0.0",
  port: 8125,
  prefix: "projecthub.#{System.get_env("METRICS_NAMESPACE") || "dev"}"

config :projecthub, http_port: 4000

config :projecthub,
  projecthub_grpc_endpoint: "0.0.0.0:50051",
  organization_grpc_endpoint: "0.0.0.0:50051",
  rbac_grpc_endpoint: "0.0.0.0:50051",
  projects_page_size: 500

config :projecthub, :enviroment, config_env()

import_config "#{config_env()}.exs"
