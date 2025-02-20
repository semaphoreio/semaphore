import Mix.Config

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :gofer, Gofer.EctoRepo,
  hostname: System.get_env("DB_HOSTNAME", "postgres"),
  username: System.get_env("DB_USERNAME", "postgres"),
  password: System.get_env("DB_PASSWORD", "postgres"),
  database: "gofer_test",
  pool_size: 10,
  log: false

config :logger, :console,
  format: "$time [$level] $message $metadata\n",
  metadata: [:extra, :reason]

config :gofer,
  start_grpc?: true,
  start_engines?: false,
  start_cache?: false,
  start_metrics?: false

config :gofer, Gofer.RBAC.RolesCache,
  cache_name: :rbac_roles,
  enabled?: true,
  expiration_ttl: 120,
  expiration_interval: 60,
  size_limit: 1_000,
  reclaim_coef: 0.5

config :gofer, Gofer.RBAC.Client,
  endpoint: System.get_env("INTERNAL_API_URL_RBAC", "localhost:51051")

config :gofer, Gofer.SecrethubClient,
  endpoint: System.get_env("INTERNAL_API_URL_SECRETHUB", "localhost:52051"),
  timeout: 10_000

config :watchman,
  host: "localhost",
  port: 8125,
  prefix: "gofer.test"

config :junit_formatter,
  report_dir: "./out",
  report_file: "results.xml",
  print_report_file: true,
  include_filename?: true,
  include_file_line?: true
