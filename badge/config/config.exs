import Config

config :badges, projecthub_grpc_endpoint: "127.0.0.1:50052"
config :badges, plumber_grpc_endpoint: "127.0.0.1:50052"

import_config "#{config_env()}.exs"
