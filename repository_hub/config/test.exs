import Config

config :repository_hub, environment: :test

config :logger, level: :debug

config :repository_hub, RepositoryHub.Repo, pool: Ecto.Adapters.SQL.Sandbox

config :junit_formatter,
  automatic_create_dir?: true,
  report_dir: "./out",
  report_file: "test-reports.xml",
  print_report_file: true,
  include_filename?: true,
  include_file_line?: true

config :tesla, adapter: Tesla.Mock

config :repository_hub, RepositoryHub.DeployKeyEncryptor, module: {RepositoryHub.FakeEncryptor, []}
config :repository_hub, RepositoryHub.WebhookSecretEncryptor, module: {RepositoryHub.FakeEncryptor, []}

config :repository_hub, RepositoryHub.RemoteIdSyncWorker, enabled: false
