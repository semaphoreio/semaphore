import Config

config :logger,
  level: :info

config :logger, :default_formatter,
  format: "[$level] $message $metadata\n",
  metadata: [:ctx, :request_id]

config :repository_hub, RepositoryHub.Repo,
  adapter: Ecto.Adapters.Postgres,
  database: System.get_env("POSTGRES_DB_NAME") || "front",
  username: System.get_env("POSTGRES_DB_USER") || "postgres",
  password: System.get_env("POSTGRES_DB_PASSWORD") || "the-cake-is-a-lie",
  hostname: System.get_env("POSTGRES_DB_HOST") || "0.0.0.0",
  pool_size: String.to_integer(System.get_env("POSTGRES_DB_POOL_SIZE") || "1"),
  parameters: [application_name: "repository_hub"]

config :tentacat,
  request_options: [
    timeout: :timer.seconds(25),
    recv_timeout: :timer.seconds(20)
  ]

config :sentry,
  included_environments: ~w(prod pre-prod),
  enable_source_code_context: true,
  root_source_code_paths: [File.cwd!()]

config :repository_hub, RepositoryHub.Repo, migration_primary_key: [id: :uuid, type: :binary_id]

config :repository_hub,
  grpc_listen_port: 50_051,
  webhook_host: System.get_env("HOOKS_HOST") || "example.com/hooks",
  ecto_repos: [RepositoryHub.Repo],
  projecthub_grpc_server: "127.0.0.1:50051",
  user_grpc_server: "127.0.0.1:50051",
  repository_integrator_grpc_server: "127.0.0.1:50051",
  organization_grpc_endpoint: "127.0.0.1:50051",
  grpc_stubs: [
    RepositoryHub.Stub.ProjectHub,
    RepositoryHub.Stub.RepositoryIntegrator,
    RepositoryHub.Stub.User,
    RepositoryHub.Stub.Organization
  ]

config :watchman,
  host: "0.0.0.0",
  port: 8125,
  prefix: "repository_hub.#{System.get_env("METRICS_NAMESPACE") || "dev"}"

import_config "#{config_env()}.exs"
