import Config

config :block, environment: :prod

config :logger, level: :info

config :logger, :console,
  format: "$time $metadata[$level] $message\n"
