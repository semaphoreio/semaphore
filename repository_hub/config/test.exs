import Config

config :repository_hub, environment: :test

config :logger, level: :debug

# Each async test holds a sandbox connection for its whole run, so the pool
# must cover the async tests ExUnit runs at once (max_cases defaults to
# 2 * schedulers). With the default pool of 1 they queue and get dropped.
config :repository_hub, RepositoryHub.Repo,
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

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
config :repository_hub, RepositoryHub.BuildStatusGuardCleanupWorker, enabled: false
config :repository_hub, github_application_id: "90709"

config FeatureProvider,
       :provider,
       {FeatureProvider.YamlProvider,
        [
          yaml_path: Path.join([__DIR__, "../test/support/fixtures/features.yaml"]),
          agent_name: :feature_provider_agent
        ]}
