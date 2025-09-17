import Mix.Config

# Configure your database
config :scheduler, Scheduler.PeriodicsRepo,
  hostname: System.get_env("DB_HOSTNAME", "postgres"),
  username: System.get_env("DB_USERNAME", "postgres"),
  password: System.get_env("DB_PASSWORD", "postgres"),
  database: "periodics_dev",
  pool_size: 10,
  show_sensitive_data_on_connection_error: true

config :scheduler, Scheduler.FrontRepo,
  hostname: System.get_env("DB_HOSTNAME", "postgres"),
  username: System.get_env("DB_USERNAME", "postgres"),
  password: System.get_env("DB_PASSWORD", "postgres"),
  database: "front_dev",
  pool_size: 10,
  show_sensitive_data_on_connection_error: true

config :watchman,
  host: "localhost",
  port: 8125,
  prefix: "periodic-sch.dev"

config :scheduler,
  feature_provider: {Scheduler.FeatureHubProvider, []}
