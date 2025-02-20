import Mix.Config

config :pipelines_api, grpc_timeout: 1_000
config :pipelines_api, wormhole_timeout: 1_000

config :watchman,
  host: "localhost",
  port: 8125,
  prefix: "ppl-api.test"

config :junit_formatter,
  report_dir: "./out",
  report_file: "results.xml",
  print_report_file: true,
  include_filename?: true,
  include_file_line?: true
