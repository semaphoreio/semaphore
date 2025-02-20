import Config

config :public_api, grpc_timeout: 3_000

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

config :public_api, :documentation_url, "http://localhost:4001"
config :public_api, :cache_timeout, 0
config :public_api, rbac_grpc_timeout: 1_000
config :public_api, permission_patrol_timeout: 1_000
