import Config

config :repository_hub, environment: :dev

config :logger, level: :debug

config :tesla, adapter: Tesla.Adapter.Hackney

config :repository_hub, RepositoryHub.DeployKeyEncryptor, module: {RepositoryHub.FakeEncryptor, []}
config :repository_hub, RepositoryHub.WebhookSecretEncryptor, module: {RepositoryHub.FakeEncryptor, []}

config FeatureProvider,
       :provider,
       {FeatureProvider.YamlProvider,
        [
          yaml_path: Path.join([__DIR__, "../test/support/fixtures/features.yaml"]),
          agent_name: :feature_provider_agent
        ]}
