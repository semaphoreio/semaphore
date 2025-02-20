import Config

# Configure your database
config :pre_flight_checks, PreFlightChecks.EctoRepo,
  hostname: System.get_env("DB_HOSTNAME", "postgres"),
  username: System.get_env("DB_USERNAME", "postgres"),
  password: System.get_env("DB_PASSWORD", "postgres"),
  database: "pre_flight_checks",
  show_sensitive_data_on_connection_error: true,
  pool_size: 10

config :pre_flight_checks, amqp_url: System.get_env("AMQP_URL", "amqp://rabbitmq:5672")

config :watchman,
  host: "localhost",
  port: 8125,
  prefix: "pre_flight_checks.dev"

config :vmstats,
  sink: VMStats.WatchmanSink,
  interval: 10_000

# Do not include metadata nor timestamps in development logs
config :logger, :console, format: "[$level] $message\n"
