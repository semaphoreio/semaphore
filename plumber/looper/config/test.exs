import Config

config :looper, Looper.Test.EctoRepo,
  adapter: Ecto.Adapters.Postgres,
  database: System.get_env("POSTGRES_DB_NAME"),
  username: System.get_env("POSTGRES_DB_USER"),
  password: System.get_env("POSTGRES_DB_PASSWORD"),
  hostname: System.get_env("POSTGRES_DB_HOST"),
  pool_size: String.to_integer(System.get_env("POSTGRES_DB_POOL_SIZE") || "1"),
  ssl: System.get_env("POSTGRES_DB_SSL") == "true" || false,
  parameters: [application_name: "plumber-looper"],
  loggers: [
    {Ecto.LogEntry, :log, [:debug]}
  ]

config :watchman,
  host: "localhost",
  port: 8125,
  prefix: "looper.test"

config :junit_formatter,
  automatic_create_dir?: true,
  report_dir: "./out",
  report_file: "test-reports.xml",
  print_report_file: true,
  include_filename?: true,
  include_file_line?: true
