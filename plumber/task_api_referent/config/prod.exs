import Config

config :logger, level: :info

# Do not print empty line between log events.
config :logger, :console,
  format: "$time $metadata[$level] $levelpad$message\n"
