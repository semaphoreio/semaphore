import Config

config :grpc,
  start_server: true,
  http2_client_adapter: GRPC.Adapter.Gun

config :logger, level: (System.get_env("LOG_LEVEL") || "debug") |> String.to_atom()

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:user_id]

config :tentacat, :deserialization_options, labels: :atom

config :tentacat, :extra_headers, [
  {"Accept", "application/vnd.github.hellcat-preview+json"}
]

config :watchman,
  host: "0.0.0.0",
  port: 8125,
  prefix: "guard.#{System.get_env("METRICS_NAMESPACE") || "dev"}"

config :guard,
  projecthub_grpc_endpoint: "127.0.0.1:50052",
  organization_grpc_endpoint: "127.0.0.1:50052",
  # sobelow_skip ["Config.Secrets"]
  secrethub_grpc_endpoint: "127.0.0.1:50052",
  pipeline_grpc_endpoint: "127.0.0.1:50052",
  repo_proxy_grpc_endpoint: "127.0.0.1:50052",
  repositoryhub_grpc_endpoint: "127.0.0.1:50052",
  feature_app_endpoint: "127.0.0.1:50052",
  instance_config_grpc_endpoint: "127.0.0.1:50051",
  rbac_grpc_endpoint: "127.0.0.1:50052",
  okta_grpc_endpoint: "127.0.0.1:50052"

config :guard, Guard.Repo,
  adapter: Ecto.Adapters.Postgres,
  database: System.get_env("POSTGRES_DB_NAME") || "guard",
  username: System.get_env("POSTGRES_DB_USER") || "postgres",
  password: System.get_env("POSTGRES_DB_PASSWORD") || "the-cake-is-a-lie",
  hostname: System.get_env("POSTGRES_DB_HOST") || "127.0.0.1",
  pool_size: String.to_integer(System.get_env("POSTGRES_DB_POOL_SIZE") || "1"),
  parameters: [application_name: "guard"],
  migration_primary_key: [name: :id, type: :binary_id],
  ssl: System.get_env("POSTGRES_DB_SSL") == "true" || false

config :guard, Guard.FrontRepo,
  adapter: Ecto.Adapters.Postgres,
  database: System.get_env("POSTGRES_FRONT_DB_NAME") || "front",
  username: System.get_env("POSTGRES_DB_USER") || "postgres",
  password: System.get_env("POSTGRES_DB_PASSWORD") || "the-cake-is-a-lie",
  hostname: System.get_env("POSTGRES_DB_HOST") || "127.0.0.1",
  pool_size: String.to_integer(System.get_env("POSTGRES_DB_POOL_SIZE") || "1"),
  parameters: [application_name: "guard"],
  ssl: System.get_env("POSTGRES_DB_SSL") == "true" || false

config :guard, Guard.InstanceConfigRepo,
  adapter: Ecto.Adapters.Postgres,
  database: System.get_env("POSTGRES_GIT_INTEGRATION_DB_NAME") || "integration_configurations",
  username: System.get_env("POSTGRES_DB_USER") || "postgres",
  password: System.get_env("POSTGRES_DB_PASSWORD") || "the-cake-is-a-lie",
  hostname: System.get_env("POSTGRES_DB_HOST") || "127.0.0.1",
  pool_size: String.to_integer(System.get_env("POSTGRES_DB_POOL_SIZE") || "1"),
  parameters: [application_name: "guard"],
  ssl: System.get_env("POSTGRES_DB_SSL") == "true" || false

config :guard, ecto_repos: [Guard.Repo, Guard.FrontRepo, Guard.InstanceConfigRepo]

config :guard, amqp_url: System.get_env("AMQP_URL") || "amqp://127.0.0.1:5672"

config :sentry,
  dsn: System.get_env("SENTRY_DSN"),
  included_environments: ~w(prod pre-prod),
  environment_name: System.get_env("SENTRY_ENV") || "development",
  enable_source_code_context: true,
  root_source_code_paths: [File.cwd!()],
  context_lines: 5

config :guard, base_domain: System.get_env("BASE_DOMAIN")
config :guard, session_secret_key_base: System.get_env("SESSION_SECRET_KEY_BASE")
config :guard, session_key: System.get_env("SESSION_COOKIE_NAME")

config :guard,
  oidc: [
    discovery_url: System.get_env("OIDC_DISCOVERY_URL"),
    client_id: System.get_env("OIDC_CLIENT_ID"),
    client_secret: System.get_env("OIDC_CLIENT_SECRET"),
    manage_url: System.get_env("OIDC_MANAGE_URL"),
    manage_client_id: System.get_env("OIDC_MANAGE_CLIENT_ID"),
    manage_client_secret: System.get_env("OIDC_MANAGE_CLIENT_SECRET")
  ]

config :ueberauth, Ueberauth,
  base_path: "/oauth",
  providers: [
    github: {Ueberauth.Strategy.Github, [default_scope: "user:email"]},
    bitbucket: {Ueberauth.Strategy.Bitbucket, []},
    gitlab:
      {Ueberauth.Strategy.Gitlab,
       [default_scope: "api read_user read_repository write_repository openid"]}
  ]

if System.get_env("AMQP_URL") != nil do
  config :amqp,
    connections: [
      amqp: [url: System.get_env("AMQP_URL")]
    ],
    channels: [
      audit: [connection: :amqp],
      authorization: [connection: :amqp],
      user: [connection: :amqp],
      organization: [connection: :amqp],
      project: [connection: :amqp],
      instance_config: [connection: :amqp]
    ]
end

config :guard, :front_git_integration_path, "/settings/git_integrations"

config :guard, Guard.OrganizationCleaner,
  jobs: [
    # Every Midnight
    {"0 0 * * *", {Guard.OrganizationCleaner, :process, []}}
  ]

config :guard, Guard.McpOAuth.AuthCodeCleaner,
  jobs: [
    # Every 30 minutes
    {"*/30 * * * *", {Guard.McpOAuth.AuthCodeCleaner, :process, []}}
  ]

config :guard, :hard_destroy_grace_period_days, 30

config :guard, :posthog_api_key, ""
config :guard, :posthog_host, "https://app.posthog.com"

import_config "#{config_env()}.exs"
