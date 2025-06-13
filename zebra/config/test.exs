import Config

config :zebra, Zebra.LegacyRepo,
    pool_size: 5,
    pool: Ecto.Adapters.SQL.Sandbox

config :logger, :console, level: :debug

config :junit_formatter,
  automatic_create_dir?: true,
  report_dir: "./out",
  report_file: "test-reports.xml",
  print_report_file: true,
  include_filename?: true,
  include_file_line?: true
