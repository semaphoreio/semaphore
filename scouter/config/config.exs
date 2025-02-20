import Config

config :scouter,
  ecto_repos: [Scouter.Repo],
  grpc_listen_port: 50_051,
  env: Mix.env()

config :scouter, Scouter.Repo,
  adapter: Ecto.Adapters.Postgres,
  parameters: [application_name: "scouter"],
  migration_primary_key: [name: :id, type: :binary_id],
  start_apps_before_migration: [:ssl]

config :watchman,
  host: "0.0.0.0",
  port: 8125,
  prefix: "scouter.#{System.get_env("METRICS_NAMESPACE") || "dev"}"

import_config "#{config_env()}.exs"
