import Config

config :watchman,
  host: "localhost",
  port: 8125,
  prefix: "spec.test"

config :junit_formatter,
  automatic_create_dir?: true,
  report_dir: "./out",
  report_file: "test-reports.xml",
  print_report_file: true,
  include_filename?: true,
  include_file_line?: true
