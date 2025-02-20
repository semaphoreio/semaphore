import Config

config :watchman,
  host: "localhost",
  port: 8125,
  prefix: "job_matrix.test"

config :junit_formatter,
  report_dir: "./out",
  report_file: "results.xml",
  print_report_file: true,
  include_filename?: true,
  include_file_line?: true
