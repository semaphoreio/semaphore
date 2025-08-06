import Config

config :notifications, environment: Mix.env()

config :notifications, http_port: 4000
config :grpc, start_server: true

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:module, :job_id],
  handle_otp_reports: true,
  handle_sasl_reports: true

import_config "_silent_lager.exs"

config :notifications, ecto_repos: [Notifications.Repo]

import_config "#{config_env()}.exs"
