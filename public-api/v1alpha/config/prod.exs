import Config

config :logger, level: (System.get_env("LOG_LEVEL") || "info") |> String.to_atom()

# Do not print empty line between log events.
config :logger, :console, format: "$time $metadata[$level] $levelpad$message\n"
