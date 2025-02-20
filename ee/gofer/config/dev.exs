import Mix.Config

# Configure your database
config :gofer, Gofer.EctoRepo,
  hostname: System.get_env("DB_HOSTNAME", "postgres"),
  username: System.get_env("DB_USERNAME", "postgres"),
  password: System.get_env("DB_PASSWORD", "postgres"),
  database: "gofer_dev",
  pool_size: 10,
  show_sensitive_data_on_connection_error: true

config :gofer,
  start_grpc?: true,
  start_engines?: true,
  start_cache?: true,
  start_metrics?: true

config :gofer, Gofer.RBAC.RolesCache,
  cache_name: :rbac_roles,
  enabled?: true,
  expiration_ttl: 120,
  expiration_interval: 60,
  size_limit: 1_000,
  reclaim_coef: 0.5

config :gofer, Gofer.RBAC.Client,
  endpoint: System.get_env("INTERNAL_API_URL_RBAC", "localhost:50051")

config :gofer, Gofer.SecrethubClient,
  endpoint: System.get_env("INTERNAL_API_URL_SECRETHUB", "localhost:50051")

config :watchman,
  host: "localhost",
  port: 8125,
  prefix: "gofer.dev"

config :logger, :console,
  level: :debug,
  format: "$time [$level] $message $metadata\n",
  metadata: [:extra, :reason]
