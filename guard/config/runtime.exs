import Config

config :guard, :migrations_path, System.get_env("MIGRATIONS_PATH") || "/app/repo/migrations"

{metric_channel, metrics_format} =
  System.get_env("ON_PREM")
  |> case do
    "true" -> {:external, :aws_cloudwatch}
    _ -> {:internal, :statsd_graphite}
  end

config :watchman,
  prefix:
    System.get_env("METRICS_PREFIX") || "guard.#{System.get_env("METRICS_NAMESPACE") || "dev"}",
  host: System.get_env("METRICS_HOST") || "0.0.0.0",
  port: (System.get_env("METRICS_PORT") || "8125") |> Integer.parse() |> elem(0),
  send_only: metric_channel,
  external_backend: metrics_format

config :guard, :restricted_org_usernames, System.get_env("RESTRICTED_ORG_USERNAMES", "")

config :guard, Guard.Repo,
  adapter: Ecto.Adapters.Postgres,
  prepare: :unnamed,
  database: System.get_env("POSTGRES_DB_NAME") || "guard",
  username: System.get_env("POSTGRES_DB_USER") || "postgres",
  password: System.get_env("POSTGRES_DB_PASSWORD") || "the-cake-is-a-lie",
  hostname: System.get_env("POSTGRES_DB_HOST") || "127.0.0.1",
  pool_size: String.to_integer(System.get_env("POSTGRES_DB_POOL_SIZE") || "1"),
  ssl: System.get_env("POSTGRES_DB_SSL") == "true" || false

config :guard, Guard.FrontRepo,
  adapter: Ecto.Adapters.Postgres,
  prepare: :unnamed,
  database: System.get_env("POSTGRES_FRONT_DB_NAME") || "front",
  username: System.get_env("POSTGRES_DB_USER") || "postgres",
  password: System.get_env("POSTGRES_DB_PASSWORD") || "the-cake-is-a-lie",
  hostname: System.get_env("POSTGRES_DB_HOST") || "127.0.0.1",
  pool_size: String.to_integer(System.get_env("POSTGRES_DB_POOL_SIZE") || "1"),
  ssl: System.get_env("POSTGRES_DB_SSL") == "true" || false

if System.get_env("START_INSTANCE_CONFIG") == "true" do
  config :guard, Guard.InstanceConfigRepo,
    adapter: Ecto.Adapters.Postgres,
    prepare: :unnamed,
    database: System.get_env("POSTGRES_GIT_INTEGRATION_DB_NAME") || "integration_configurations",
    username: System.get_env("POSTGRES_DB_USER") || "postgres",
    password: System.get_env("POSTGRES_DB_PASSWORD") || "the-cake-is-a-lie",
    hostname: System.get_env("POSTGRES_DB_HOST") || "127.0.0.1",
    pool_size: String.to_integer(System.get_env("POSTGRES_DB_POOL_SIZE") || "1"),
    ssl: System.get_env("POSTGRES_DB_SSL") == "true" || false
end

config :guard, amqp_url: System.get_env("AMQP_URL") || "amqp://127.0.0.1:5672"

config :sentry,
  dsn: System.get_env("SENTRY_DSN"),
  included_environments: ~w(prod pre-prod),
  environment_name: System.get_env("SENTRY_ENV") || "development",
  enable_source_code_context: true,
  root_source_code_paths: [File.cwd!()],
  context_lines: 5

config :guard, base_domain: System.get_env("BASE_DOMAIN")
config :guard, session_secret_key_base: System.get_env("SESSION_SECRET_KEY_BASE")
config :guard, session_key: System.get_env("SESSION_COOKIE_NAME")

config :guard,
  github_app_redirect_url:
    "https://id.#{System.get_env("BASE_DOMAIN")}/github_app_manifest_callback"

config :guard, on_prem: System.get_env("ON_PREM") == "true"

config :guard, root_login: System.get_env("ROOT_LOGIN") == "true"

config :guard,
  root_login_methods: (System.get_env("ROOT_LOGIN_METHODS") || "github") |> String.split(",")

config :guard, default_login_method: System.get_env("DEFAULT_LOGIN_METHOD") || "local"
config :guard, keycloak_login_page: System.get_env("KEYCLOAK_LOGIN_PAGE") == "true"

if config_env() == :prod do
  config :logger, level: (System.get_env("LOG_LEVEL") || "info") |> String.to_atom()

  feature_provider =
    System.get_env("FEATURE_YAML_PATH")
    |> case do
      nil ->
        {Guard.FeatureHubProvider,
         [
           cache: {FeatureProvider.CachexCache, name: :feature_provider_cache}
         ]}

      path ->
        {FeatureProvider.YamlProvider, [yaml_path: path, agent_name: :feature_provider_agent]}
    end

  config :guard, feature_provider: feature_provider

  config :guard, Guard.OIDC.TokenEncryptor,
    module: {Guard.GRPCEncryptor, url: System.get_env("ENCRYPTOR_URL")}

  config :guard, Guard.InstanceConfig.Encryptor,
    module: {Guard.GRPCEncryptor, url: System.get_env("ENCRYPTOR_URL")}

  config :guard,
    trusted_proxies:
      System.get_env("LOAD_BALANCER_IP", "")
      |> String.split(",")
      |> Enum.map(fn s -> String.trim(s) end)
      |> Enum.filter(& &1)
      |> Enum.filter(&(&1 != ""))

  config :guard, :include_instance_config, System.get_env("INCLUDE_INSTANCE_CONFIG") == "true"

  config :guard, :github,
    client_id: System.get_env("GITHUB_CLIENT_ID"),
    client_secret: System.get_env("GITHUB_CLIENT_SECRET")

  config :guard, :bitbucket,
    client_id: System.get_env("BITBUCKET_CLIENT_ID"),
    client_secret: System.get_env("BITBUCKET_CLIENT_SECRET")

  config :guard, :gitlab,
    client_id: System.get_env("GITLAB_CLIENT_ID"),
    client_secret: System.get_env("GITLAB_CLIENT_SECRET")

  config :ueberauth, Ueberauth.Strategy.Github.OAuth,
    client_id: System.get_env("GITHUB_CLIENT_ID"),
    client_secret: System.get_env("GITHUB_CLIENT_SECRET")

  config :ueberauth, Ueberauth.Strategy.Bitbucket.OAuth,
    client_id: System.get_env("BITBUCKET_CLIENT_ID"),
    client_secret: System.get_env("BITBUCKET_CLIENT_SECRET")

  config :ueberauth, Ueberauth.Strategy.Gitlab.OAuth,
    client_id: System.get_env("GITLAB_CLIENT_ID"),
    client_secret: System.get_env("GITLAB_CLIENT_SECRET"),
    redirect_uri: "https://id.#{System.get_env("BASE_DOMAIN")}/oauth/gitlab/callback"

  config :guard,
    oidc: [
      discovery_url: System.get_env("OIDC_DISCOVERY_URL"),
      client_id: System.get_env("OIDC_CLIENT_ID"),
      client_secret: System.get_env("OIDC_CLIENT_SECRET"),
      manage_url: System.get_env("OIDC_MANAGE_URL"),
      manage_client_id: System.get_env("OIDC_MANAGE_CLIENT_ID"),
      manage_client_secret: System.get_env("OIDC_MANAGE_CLIENT_SECRET")
    ]

  config :guard,
    projecthub_grpc_endpoint: System.fetch_env!("INTERNAL_API_URL_PROJECT"),
    secrethub_grpc_endpoint: System.fetch_env!("INTERNAL_API_URL_SECRETHUB"),
    organization_grpc_endpoint: System.fetch_env!("INTERNAL_API_URL_ORGANIZATION"),
    pipeline_grpc_endpoint: System.fetch_env!("INTERNAL_API_URL_PLUMBER"),
    repo_proxy_grpc_endpoint: System.fetch_env!("INTERNAL_API_URL_REPO_PROXY"),
    repositoryhub_grpc_endpoint: System.fetch_env!("INTERNAL_API_URL_REPOSITORY"),
    feature_api_endpoint: System.fetch_env!("INTERNAL_API_URL_FEATURE"),
    instance_config_grpc_endpoint: System.fetch_env!("INTERNAL_API_URL_INSTANCE_CONFIG"),
    rbac_grpc_endpoint: System.fetch_env!("INTERNAL_API_URL_RBAC"),
    okta_grpc_endpoint: System.fetch_env!("INTERNAL_API_URL_OKTA")
end

config :guard, :token_hashing_salt, System.get_env("TOKEN_HASHING_SALT")

config :guard, ignore_refresh_requests: System.get_env("IGNORE_REFRESH_REQUESTS") == "true"

config :guard,
       :hide_gitlab_login_page,
       System.get_env("HIDE_GITLAB_LOGIN_PAGE") == "true"

config :guard, :posthog_api_key, System.get_env("POSTHOG_API_KEY")
config :guard, :posthog_host, System.get_env("POSTHOG_HOST") || "https://app.posthog.com"

if System.get_env("AMQP_URL") != nil do
  config :amqp,
    connections: [
      amqp: [
        url: System.get_env("AMQP_URL"),
        name: "#{System.get_env("HOSTNAME", "guard")}"
      ]
    ],
    channels: [
      audit: [connection: :amqp],
      authorization: [connection: :amqp],
      user: [connection: :amqp],
      organization: [connection: :amqp],
      project: [connection: :amqp],
      instance_config: [connection: :amqp]
    ]
end

if System.get_env("TLS_SKIP_VERIFY_INTERNAL") == "true" do
  config :openid_connect, finch_transport_opts: [verify: :verify_none]
end
