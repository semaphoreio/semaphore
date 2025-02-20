import Config

config :secrethub, :environment, config_env()

# Configures Elixir's Logger
config :logger, :console,
  level: :info,
  truncate: 16096,
  format: "$time $metadata[$level] $message\n",
  metadata: [:module, :job_id],
  handle_otp_reports: true,
  handle_sasl_reports: true

config :secrethub, openid_connect_http_port: 5000
config :secrethub, openid_keys_cache_max_age_in_s: 0
config :secrethub, grpc_port: 50_051
config :grpc, start_server: true

config :secrethub,
  rbac_grpc_endpoint: "127.0.0.1:50051",
  feature_api_endpoint: "127.0.0.1:50051",
  projecthub_grpc_endpoint: "127.0.0.1:50051"

config :secrethub, ecto_repos: [Secrethub.Repo]

import_config "#{config_env()}.exs"
