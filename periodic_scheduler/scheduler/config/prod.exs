import Mix.Config

config :logger, level: :info

# Do not print empty line between log events.
config :logger, :console, format: "$time $metadata[$level] $message\n"

# How long should we retry to schedule a workflow (5 minutes in seconds)
config :scheduler, max_scheduling_duration: 300
