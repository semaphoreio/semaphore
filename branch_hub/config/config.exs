use Mix.Config

config :grpc, start_server: true

# Number of log lines per second
config :logger, :console, max_buffer: 100

# Do not print empty line between log events.
config :logger, :console, format: "$time $metadata[$level] $levelpad$message\n"

config :logger, backends: [:console, Sentry.LoggerBackend]

config :branch_hub, ecto_repos: [BranchHub.Repo]

config :branch_hub, BranchHub.Repo, migration_primary_key: [id: :uuid, type: :binary_id]

import_config "#{Mix.env()}.exs"
