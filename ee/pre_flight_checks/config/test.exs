import Config

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :pre_flight_checks, PreFlightChecks.EctoRepo,
  hostname: System.get_env("DB_HOSTNAME", "postgres"),
  username: System.get_env("DB_USERNAME", "postgres"),
  password: System.get_env("DB_PASSWORD", "postgres"),
  database: "pre_flight_checks",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10

config :pre_flight_checks, amqp_url: System.get_env("AMQP_URL", "amqp://rabbitmq:5672")

config :watchman,
  host: "localhost",
  port: 8125,
  prefix: "pre_flight_checks.test"

config :junit_formatter,
  report_dir: ".",
  report_file: "test-results.xml",
  print_report_file: true,
  include_filename?: true,
  include_file_line?: true

config :vmstats,
  sink: VMStats.WatchmanSink,
  interval: 10_000

# Print only warnings and errors during test
config :logger, level: :warn

config :logger, :console,
  level: :emergency,
  format: "$time $metadata[$level] $message\n"
