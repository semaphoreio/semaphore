import Config

config :hooks_processor, environment: config_env()

config :logger, :console, format: "$time $metadata[$level] $message\n"

config :hooks_processor,
  ecto_repos: [HooksProcessor.EctoRepo]

config :hooks_processor, HooksProcessor.EctoRepo,
  adapter: Ecto.Adapters.Postgres,
  parameters: [application_name: "hooks-processor"],
  loggers: [
    {Ecto.LogEntry, :log, [:debug]}
  ]

config :postgrex, :json_library, JSON

config :watchman,
  host: "localhost",
  port: 8125,
  prefix: "hooks_processor.test"

# Number of log lines per second
config :logger, :console, max_buffer: 100

# Do not log debug info
config :logger, level: :info

config :sentry,
  enable_source_code_context: true,
  root_source_code_paths: [File.cwd!()],
  context_lines: 5

import_config "#{config_env()}.exs"
