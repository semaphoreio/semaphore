import Config

config :ephemeral_environments,
  ecto_repos: [EphemeralEnvironments.Repo],
  grpc_listen_port: 50_051,
  env: Mix.env()

config :ephemeral_environments, EphemeralEnvironments.Repo,
  adapter: Ecto.Adapters.Postgres,
  parameters: [application_name: "ephemeral_environments"],
  migration_primary_key: [name: :id, type: :binary_id],
  start_apps_before_migration: [:ssl]

config :watchman,
  host: "0.0.0.0",
  port: 8125,
  prefix: "ephemeral_environments.#{System.get_env("METRICS_NAMESPACE") || "dev"}"

import_config "#{config_env()}.exs"
