import Config

config :zebra, Zebra.LegacyRepo,
    pool_size: 5,
    pool: Ecto.Adapters.SQL.Sandbox

config :logger, :console, level: :debug

config :junit_formatter,
  report_dir: "./out",
  report_file: "results.xml",
  # Adds information about file location when suite finishes
  print_report_file: true,
  # Include filename and file number for more insights
  include_filename?: true,
  include_file_line?: true
