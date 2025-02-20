import Config

config :guard, environment: :test

config :guard, Guard.Repo,
  database: "guard_test",
  pool: Ecto.Adapters.SQL.Sandbox

config :guard, Guard.FrontRepo,
  database: "front_test",
  pool: Ecto.Adapters.SQL.Sandbox

config :guard, Guard.InstanceConfigRepo,
  database: "instance_config_test",
  pool: Ecto.Adapters.SQL.Sandbox

config :guard, :github,
  client_id: "github_client_id",
  client_secret: "github_client_secret"

config :guard, :bitbucket,
  client_id: "bitbucket_client_id",
  client_secret: "bitbucket_client_secret"

config :guard, :gitlab,
  client_id: "gitlab_client_id",
  client_secret: "gitlab_client_secret"

config :junit_formatter,
  report_dir: "./out",
  report_file: "results.xml",
  print_report_file: true,
  include_filename?: true,
  include_file_line?: true

config :exvcr,
  vcr_cassette_library_dir: "test/fixture/vcr_cassettes",
  filter_sensitive_data: [
    [pattern: "token [^\"]+", placeholder: "token yourtokencomeshere"]
  ],
  ignore_localhost: true

config :guard, trusted_proxies: ["127.0.0.1"]

config :guard, feature_provider: {Support.StubbedProvider, []}
config :guard, Guard.OIDC.TokenEncryptor, module: {Guard.FakeEncryptor, []}

config :tesla, adapter: Tesla.Mock
config :oauth2, adapter: Tesla.Mock
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

config :guard,
       :hide_gitlab_login_page,
       false
