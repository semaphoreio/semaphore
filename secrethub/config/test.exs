import Config

config :junit_formatter,
  automatic_create_dir?: true,
  report_dir: "./out",
  report_file: "test-reports.xml",
  print_report_file: true,
  include_filename?: true,
  include_file_line?: true

config :secrethub, Secrethub.Repo, pool: Ecto.Adapters.SQL.Sandbox

config :logger, level: :debug
