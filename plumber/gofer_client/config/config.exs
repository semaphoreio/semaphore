import Config

config :watchman,
    host: "localhost",
    port: 8125,
    prefix: "gofer_client.env-missing"

  config :grpc,
    start_server: true,
    http2_client_adapter: GRPC.Adapter.Gun

# Time to wait for gofer response
config :gofer_client, gofer_grpc_timeout: 4_567

import_config "#{config_env()}.exs"
