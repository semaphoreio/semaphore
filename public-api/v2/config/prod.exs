import Config

# Do not print empty line between log events.
config :logger, :console,
  level: (System.get_env("LOG_LEVEL") || "info") |> String.to_atom(),
  format: "$time $metadata[$level] $message\n"

config :logger, :default_handler, formatter: {LoggerJSON.Formatters.GoogleCloud, []}

config :public_api, rbac_grpc_timeout: 15_000
config :public_api, permission_patrol_timeout: 15_000
