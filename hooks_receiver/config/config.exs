import Config

config :hooks_receiver, :environment, config_env()

config :watchman,
  host: "localhost",
  port: 8125,
  prefix: "hooks_receiver.test"

# Number of log lines per second
config :logger, :console, max_buffer: 100

# Do not log debug info
config :logger, level: :info

if Mix.env() == :prod do
  config :hooks_receiver, domain: System.get_env("BASE_DOMAIN")
else
  config :hooks_receiver, domain: "semaphoretest.test"
end

import_config "#{config_env()}.exs"
