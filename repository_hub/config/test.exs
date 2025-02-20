import Config

config :repository_hub, environment: :test

config :logger, level: :debug

config :repository_hub, RepositoryHub.Repo, pool: Ecto.Adapters.SQL.Sandbox

config :junit_formatter,
  report_dir: "./out",
  report_file: "results.xml",
  # Adds information about file location when suite finishes
  print_report_file: true,
  # Include filename and file number for more insights
  include_filename?: true,
  include_file_line?: true

config :tesla, adapter: Tesla.Mock

config :repository_hub, RepositoryHub.DeployKeyEncryptor, module: {RepositoryHub.FakeEncryptor, []}
config :repository_hub, RepositoryHub.WebhookSecretEncryptor, module: {RepositoryHub.FakeEncryptor, []}
