import Config

config :guard, environment: :dev

config :unplug, :init_mode, :runtime

config :guard, trusted_proxies: ["127.0.0.1"]

config :guard, feature_provider: {Support.StubbedProvider, []}
config :guard, Guard.OIDC.TokenEncryptor, module: {Guard.FakeEncryptor, []}

config :guard, :github,
  client_id: "github_client_id",
  client_secret: "github_client_secret"

config :guard, :bitbucket,
  client_id: "bitbucket_client_id",
  client_secret: "bitbucket_client_secret"

config :guard, :gitlab,
  client_id: "gitlab_client_id",
  client_secret: "gitlab_client_secret"

config :tesla, adapter: Tesla.Adapter.Hackney
config :oauth2, adapter: Tesla.Adapter.Hackney
config :oauth2, debug: true

config :ueberauth, Ueberauth.Strategy.Github.OAuth,
  client_id: "github_client_id",
  client_secret: "github_client_secret"

config :ueberauth, Ueberauth.Strategy.Bitbucket.OAuth,
  client_id: "bitbucket_client_id",
  client_secret: "bitbucket_client_secret"

config :ueberauth, Ueberauth.Strategy.Gitlab.OAuth,
  client_id: "gitlab_client_id",
  client_secret: "gitlab_client_secret"

config :guard, Guard.InstanceConfig.Encryptor, module: {Guard.FakeEncryptor, []}
