import Config

config :rbac, environment: :test

config :rbac, Rbac.Repo,
  database: "rbac_ce_test",
  pool: Ecto.Adapters.SQL.Sandbox

config :rbac,
  user_api_grpc_endpoint: "localhost:50052",
  projecthub_grpc_endpoint: "localhost:50052"

config :junit_formatter,
  report_dir: "./out",
  report_file: "results.xml",
  print_report_file: true,
  include_filename?: true,
  include_file_line?: true

config :rbac, feature_provider: {Support.StubbedProvider, []}
config :rbac, Rbac.OIDC.TokenEncryptor, module: {Rbac.FakeEncryptor, []}
