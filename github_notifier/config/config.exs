import Config

config :github_notifier,
  pipeline_grpc_endpoint: "0.0.0.0:50052",
  projecthub_grpc_endpoint: "0.0.0.0:50052",
  organization_grpc_endpoint: "0.0.0.0:50052",
  hook_api_grpc_endpoint: "0.0.0.0:50052",
  repositoryhub_api_grpc_endpoint: "0.0.0.0:50052",
  velocityhub_api_grpc_endpoint: "0.0.0.0:50052",
  feature_grpc_endpoint: "0.0.0.0:50052"

import_config "#{config_env()}.exs"
