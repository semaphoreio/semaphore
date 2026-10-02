import Config

config :logger, :console, metadata: [:request_id]

config :github_notifier,
  # Upper bound (ms) for each dependency fetch, matching the 30s gRPC deadline
  # the Models use. See GithubNotifier.Notifier for why.
  fetch_timeout: 30_000,
  pipeline_grpc_endpoint: "0.0.0.0:50052",
  projecthub_grpc_endpoint: "0.0.0.0:50052",
  organization_grpc_endpoint: "0.0.0.0:50052",
  hook_api_grpc_endpoint: "0.0.0.0:50052",
  repositoryhub_api_grpc_endpoint: "0.0.0.0:50052",
  velocityhub_api_grpc_endpoint: "0.0.0.0:50052",
  feature_grpc_endpoint: "0.0.0.0:50052"

import_config "#{config_env()}.exs"
