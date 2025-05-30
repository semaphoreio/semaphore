import Mix.Config

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
# Configure your database
config :scheduler, Scheduler.PeriodicsRepo,
  hostname: System.get_env("DB_HOSTNAME", "postgres"),
  username: System.get_env("DB_USERNAME", "postgres"),
  password: System.get_env("DB_PASSWORD", "postgres"),
  database: "periodics_test",
  pool_size: 10,
  show_sensitive_data_on_connection_error: true

config :scheduler, Scheduler.FrontRepo,
  hostname: System.get_env("DB_HOSTNAME", "postgres"),
  username: System.get_env("DB_USERNAME", "postgres"),
  password: System.get_env("DB_PASSWORD", "postgres"),
  database: "front_test",
  pool_size: 10,
  show_sensitive_data_on_connection_error: true

# How long should we retry to schedule a workflow (in seconds)
config :scheduler, max_scheduling_duration: 2

config :watchman,
  host: "localhost",
  port: 8125,
  prefix: "periodic-sch.test"

config :junit_formatter,
  automatic_create_dir?: true,
  report_dir: "./out",
  report_file: "test-reports.xml",
  print_report_file: true,
  include_filename?: true,
  include_file_line?: true

# Print only warnings and errors during test
config :logger, level: :warn

config :scheduler,
  feature_provider: {Scheduler.FeatureHubProvider, []}
