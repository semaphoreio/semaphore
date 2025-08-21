import Config

config :front, FrontWeb.Endpoint, server: true, secret_key_base: System.get_env("SECRET_KEY_BASE")

config :front, :signing_salt, System.get_env("SESSION_SIGNING_SALT")

if System.get_env("TZDATA_DATA_DIRECTORY") != nil do
  config :tzdata, :data_dir, System.get_env("TZDATA_DATA_DIRECTORY")
else
  config :tzdata, :autoupdate, :disabled
end

{metric_channel, metrics_format} =
  System.get_env("ON_PREM")
  |> case do
    "true" -> {:external, :aws_cloudwatch}
    _ -> {:internal, :statsd_graphite}
  end

config :watchman,
  host: System.get_env("METRICS_HOST") || "0.0.0.0",
  port: (System.get_env("METRICS_PORT") || "8125") |> Integer.parse() |> elem(0),
  send_only: metric_channel,
  external_backend: metrics_format,
  prefix:
    System.get_env("METRICS_PREFIX") || "front.#{System.get_env("METRICS_NAMESPACE") || "dev"}"

config :front, amqp_url: System.get_env("AMQP_URL") || "amqp://127.0.0.1:5672"
config :front, cache_reactor_env: System.get_env("REACTOR_ENV")
config :front, start_reactor: System.get_env("START_REACTOR")
config :front, start_telemetry: System.get_env("START_TELEMETRY")
config :front, preheat_project_page: System.get_env("PREHEAT_PROJECT_PAGE")

# Configures the telemetry scheduler cron jobs
config :front, Front.Telemetry.Scheduler,
  jobs: [
    {System.get_env("TELEMETRY_CRON", "0 0 * * *"), {Front.Telemetry, :perform, []}}
  ]

config :front,
  ce_version: System.get_env("CE_VERSION", "Invalid Version")

config :sentry,
  filter: Front.SentryEventFilter,
  dsn: System.get_env("SENTRY_DSN"),
  environment_name: System.get_env("SENTRY_ENV") || "development",
  enable_source_code_context: true,
  root_source_code_paths: [File.cwd!()],
  context_lines: 5

config :front,
  cache_prefix: System.get_env("CACHE_PREFIX") || "front/",
  cache_host: System.get_env("CACHE_HOST") || "localhost",
  cache_port: elem(Integer.parse(System.get_env("CACHE_PORT") || "6379"), 0),
  cache_pool_size: elem(Integer.parse(System.get_env("CACHE_POOL_SIZE") || "5"), 0),
  github_app_url: System.get_env("GITHUB_APPLICATION_URL"),
  cookie_name: System.get_env("COOKIE_NAME"),
  use_rbac_api: if(System.get_env("USE_RBAC_API") == "true", do: true, else: false)

on_prem? = if(System.get_env("ON_PREM") == "true", do: true, else: false)

# Internal API endpoints - always read from environment variables for all environments
# Test environment will need these env vars set, or use stubs in test setup
config :front,
  artifacthub_api_grpc_endpoint: System.fetch_env!("INTERNAL_API_URL_ARTIFACTHUB"),
  audit_grpc_endpoint: System.fetch_env!("INTERNAL_API_URL_AUDIT"),
  authentication_grpc_endpoint: System.fetch_env!("INTERNAL_API_URL_AUTHENTICATION"),
  billing_api_grpc_endpoint: System.fetch_env!("INTERNAL_API_URL_BILLING"),
  branch_api_grpc_endpoint: System.fetch_env!("INTERNAL_API_URL_BRANCH"),
  dashboard_api_grpc_endpoint: System.fetch_env!("INTERNAL_API_URL_DASHBOARDHUB"),
  feature_grpc_endpoint: System.fetch_env!("INTERNAL_API_URL_FEATURE"),
  guard_grpc_endpoint: System.fetch_env!("INTERNAL_API_URL_GUARD"),
  guard_user_grpc_endpoint: System.fetch_env!("INTERNAL_API_URL_USER"),
  hooks_grpc_endpoint: System.fetch_env!("INTERNAL_API_URL_HOOKS"),
  instance_config_grpc_endpoint: System.fetch_env!("INTERNAL_API_URL_INSTANCE_CONFIG"),
  job_api_grpc_endpoint: System.fetch_env!("INTERNAL_API_URL_JOB"),
  loghub2_api_grpc_endpoint: System.fetch_env!("INTERNAL_API_URL_LOGHUB2"),
  notification_api_grpc_endpoint: System.fetch_env!("INTERNAL_API_URL_NOTIFICATION"),
  okta_grpc_endpoint: System.fetch_env!("INTERNAL_API_URL_OKTA"),
  organization_api_grpc_endpoint: System.fetch_env!("INTERNAL_API_URL_ORGANIZATION"),
  periodic_scheduler_grpc_endpoint: System.fetch_env!("INTERNAL_API_URL_SCHEDULER"),
  pipeline_api_grpc_endpoint: System.fetch_env!("INTERNAL_API_URL_PLUMBER"),
  ppl_grpc_endpoint: System.fetch_env!("INTERNAL_API_URL_PLUMBER"),
  pre_flight_checks_grpc_endpoint: System.fetch_env!("INTERNAL_API_URL_PFC"),
  projecthub_grpc_endpoint: System.fetch_env!("INTERNAL_API_URL_PROJECT"),
  rbac_grpc_endpoint: System.fetch_env!("INTERNAL_API_URL_RBAC"),
  repo_proxy_grpc_endpoint: System.fetch_env!("INTERNAL_API_URL_REPO_PROXY"),
  repohub_grpc_endpoint: System.fetch_env!("INTERNAL_API_URL_REPOHUB"),
  repository_integrator_grpc_endpoint:
    System.fetch_env!("INTERNAL_API_URL_REPOSITORY_INTEGRATOR"),
  repositoryhub_grpc_endpoint: System.fetch_env!("INTERNAL_API_URL_REPOSITORY"),
  scouter_grpc_endpoint: System.fetch_env!("INTERNAL_API_URL_SCOUTER"),
  # sobelow_skip ["Config.Secrets"]
  secrets_api_grpc_endpoint: System.fetch_env!("INTERNAL_API_URL_SECRETHUB"),
  self_hosted_agents_grpc_endpoint: System.fetch_env!("INTERNAL_API_URL_SELFHOSTEDHUB"),
  superjerry_grpc_endpoint: System.fetch_env!("INTERNAL_API_URL_SUPERJERRY"),
  task_grpc_endpoint: System.fetch_env!("INTERNAL_API_URL_TASK"),
  velocity_grpc_endpoint: System.fetch_env!("INTERNAL_API_URL_VELOCITY"),
  workflow_api_grpc_endpoint: System.fetch_env!("INTERNAL_API_URL_PLUMBER"),
  jwt_grpc_endpoint: System.fetch_env!("INTERNAL_API_URL_SECRETHUB"),
  service_account_grpc_endpoint: System.fetch_env!("INTERNAL_API_URL_SERVICE_ACCOUNT"),
  permission_patrol_grpc_endpoint: "127.0.0.1:50052"

config :front,
  license_grpc_endpoint: System.get_env("INTERNAL_API_URL_LICENSE_CHECKER"),
  gofer_grpc_endpoint: System.get_env("INTERNAL_API_URL_GOFER"),
  groups_grpc_endpoint: System.get_env("INTERNAL_API_URL_GROUPS"),
  loghub_api_grpc_endpoint: System.get_env("INTERNAL_API_URL_LOGHUB")

if config_env() == :prod do
  config :logger, level: (System.get_env("LOG_LEVEL") || "info") |> String.to_atom()
  config :front, docs_domain: System.get_env("DOCS_DOMAIN", "docs.semaphoreci.com")
  config :front, domain: System.get_env("BASE_DOMAIN")
  config :front, :userpilot_token, System.get_env("USERPILOT_TOKEN")
  config :front, :get_started_path, System.get_env("GETTING_STARTED_YAML_PATH")

  config :front,
         :connect_github_app_url,
         "https://id.#{System.get_env("BASE_DOMAIN")}/github_app_manifest"

  # Support Client tokens
  config :front,
    support_app_id: System.get_env("HELPSCOUT_APP_ID"),
    support_app_secret: System.get_env("HELPSCOUT_APP_SECRET")
end

config :front,
  zendesk_support_url: System.get_env("ZENDESK_SUPPORT_URL") || "http://support.semaphoreci.test",
  zendesk_jwt_url: System.get_env("ZENDESK_JWT_URL") || "http://support.semaphoreci.test",
  zendesk_jwt_secret: System.get_env("ZENDESK_JWT_SECRET") || "secret",
  zendesk_snippet_id: System.get_env("ZENDESK_SNIPPET_ID"),
  google_gtag: System.get_env("GOOGLE_GTAG")

config :front, :on_prem?, on_prem?

if on_prem? do
  config :front,
    feature_provider:
      {FeatureProvider.YamlProvider,
       [yaml_path: System.get_env("FEATURE_YAML_PATH"), agent_name: :feature_provider_agent]}

  config :front, JobPage.Api.Loghub, timeout: :timer.minutes(2)
else
  config :front,
    feature_provider:
      {Front.FeatureHubProvider,
       [
         cache:
           {FeatureProvider.CachexCache,
            name: :feature_provider_cache, ttl_ms: :timer.minutes(10)}
       ]}
end

if System.get_env("AMQP_URL") != nil do
  config :amqp,
    connections: [
      amqp: [
        url: System.get_env("AMQP_URL"),
        name: "#{System.get_env("HOSTNAME", "front")}"
      ]
    ],
    channels: [
      audit: [connection: :amqp]
    ]
end

config :front, :audit_logging, System.get_env("AUDIT_LOGGING") == "true"

config :front, :ce_roles, System.get_env("CE_ROLES") == "true"

config :front,
       :hide_promotions,
       System.get_env("HIDE_PROMOTIONS") == "true"

config :front,
       :workflow_templates_path,
       System.fetch_env!("WORKFLOW_TEMPLATES_YAMLS_PATH")

config :front,
       :new_project_onboarding_workflow_templates_path,
       System.fetch_env!("WORKFLOW_TEMPLATES_YAMLS_PATH") <> "_new"

config :front,
       :hide_bitbucket_me_page,
       System.get_env("HIDE_BITBUCKET_ME_PAGE") == "true"

config :front,
       :hide_gitlab_me_page,
       System.get_env("HIDE_GITLAB_ME_PAGE") == "true"

config :front,
       :single_tenant,
       System.get_env("SINGLE_TENANT") == "true"

config :front,
       :edition,
       System.get_env("EDITION", "") |> String.trim() |> String.downcase()
