import Config

config :watchman,
  host: "localhost",
  port: 8125,
  prefix: "ppl-api.dev"

config :public_api, :documentation_url, "http://localhost:4001"

config :logger, :backends, [Logger.Backends.Console]

config :public_api, rbac_grpc_timeout: 1_000
config :public_api, permission_patrol_timeout: 1_000
