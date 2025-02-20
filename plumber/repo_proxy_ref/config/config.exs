import Config

config :watchman,
    host: "localhost",
    port: 8125,
    prefix: "repo-proxy-ref.env-missing"

config :grpc,
  start_server: true
