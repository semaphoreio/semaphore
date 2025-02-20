import Config

config :watchman,
  host: System.get_env("METRICS_HOST") || "statsd",
  port: (System.get_env("METRICS_PORT") || "8125") |> Integer.parse() |> elem(0),
  prefix: "looper.test"

config :looper,
  ecto_repos: [Looper.Test.EctoRepo]

config :looper, Looper.Test.EctoRepo,
  priv: "test",
  adapter: Ecto.Adapters.Postgres,
  parameters: [application_name: "plumber-looper"]

# disable logging of ecto queries
config :logger, level: :info
# for debugging queries
# config :logger, level: :debug

import_config "#{config_env()}.exs"
