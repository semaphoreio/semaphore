import Mix.Config

config :logger, level: :info

# Do not print empty line between log events.
config :logger, :console,
  format: "$time [$level] $message (( $metadata))\n",
  metadata: [:extra, :reason, :file, :line]
