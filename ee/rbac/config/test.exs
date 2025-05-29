import Config

config :rbac, environment: :test

config :rbac, Rbac.Repo,
  database: "guard_test",
  pool: Ecto.Adapters.SQL.Sandbox

config :rbac, Rbac.FrontRepo,
  database: "front_test",
  pool: Ecto.Adapters.SQL.Sandbox

config :junit_formatter,
  automatic_create_dir?: true,
  report_dir: "./out",
  report_file: "test-reports.xml",
  print_report_file: true,
  include_filename?: true,
  include_file_line?: true

config :rbac, feature_provider: {Support.StubbedProvider, []}
config :rbac, Rbac.OIDC.TokenEncryptor, module: {Rbac.FakeEncryptor, []}

config :tesla, adapter: Tesla.Mock
