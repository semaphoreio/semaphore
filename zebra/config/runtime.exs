import Config

#
# Database configuration
#

config :zebra, Zebra.LegacyRepo,
  adapter: Ecto.Adapters.Postgres,
  database: System.get_env("POSTGRES_DB_NAME") || "front",
  username: System.get_env("POSTGRES_DB_USER") || "postgres",
  password: System.get_env("POSTGRES_DB_PASSWORD") || "the-cake-is-a-lie",
  hostname: System.get_env("POSTGRES_DB_HOST") || "0.0.0.0",
  pool_size: String.to_integer(System.get_env("POSTGRES_DB_POOL_SIZE") || "1"),
  loggers: [
    {Ecto.LogEntry, :log, [:debug]},
    {Watchman.Ecto, :log, ["zebra"]}
  ],
  parameters: [application_name: "zebra"],
  ssl: System.get_env("POSTGRES_DB_SSL") == "true" || false,
  ssl_opts: [
    verify: :verify_none
  ]

#
# Custom modules configuration
#

config :zebra, Zebra.Workers.JobRequestFactory,
  broker_url: System.get_env("JOB_CALLBACK_BROKER_URL") || "s2-callback.semaphoretest.xyz",
  timeout: 1_000

config :zebra, Zebra.Workers.WaitingJobTerminator,
  max_scheduled_time_in_seconds: System.get_env("MAX_SCHEDULED_TIME_IN_SECONDS") || "86400"

config :zebra, Zebra.Workers.JobDeletionPolicyWorker,
  naptime: String.to_integer(System.get_env("JOB_DELETION_POLICY_WORKER_NAPTIME_MS") || "60000"),
  longnaptime: String.to_integer(System.get_env("JOB_DELETION_POLICY_WORKER_LONGNAPTIME_MS") || "600000"),
  batch_size: String.to_integer(System.get_env("JOB_DELETION_POLICY_WORKER_BATCH_SIZE") || "100")

config :zebra, Zebra.Workers.JobDeletionPolicyMarker,
  days: String.to_integer(System.get_env("JOB_DELETION_POLICY_MARKER_GRACE_PERIOD_DAYS") || "15"),
  batch_size: String.to_integer(System.get_env("JOB_DELETION_POLICY_MARKER_BATCH_SIZE") || "1000")

#
# Feature provider configuration
#

if config_env() == :prod do
  feature_provider =
    System.get_env("FEATURE_YAML_PATH")
    |> case do
      nil ->
        {Zebra.FeatureHubProvider,
          [
            cache: {FeatureProvider.CachexCache, name: :feature_provider_cache, ttl_ms: :timer.hours(6)}
          ]}
      path ->
        {FeatureProvider.YamlProvider, [yaml_path: path, agent_name: :feature_provider_agent]}
    end

  config :zebra, feature_provider: feature_provider
else
  config :zebra, feature_provider: {Support.MockedProvider, []}
end

#
# AMQP configuration
#

config :zebra, amqp_url: System.get_env("AMQP_URL") || "amqp://127.0.0.1:5672"

if System.get_env("AMQP_URL") != nil do
  config :amqp,
    connections: [
      amqp: [url: System.get_env("AMQP_URL"), name: "#{System.get_env("HOSTNAME", "zebra")}"]
    ],
    channels: [
      task_finisher: [connection: :amqp],
      job_finisher: [connection: :amqp],
      job_deletion: [connection: :amqp]
    ]
end

#
# statsd configuration
#

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
    System.get_env("METRICS_PREFIX") || "zebra.#{System.get_env("METRICS_NAMESPACE") || "dev"}"

config :sentry,
  dsn: System.get_env("SENTRY_DSN"),
  filter: Zebra.SentryFilter,
  environment_name: config_env(),
  tags: %{
    application: "zebra"
  },
  included_environments: []

if config_env() == :prod do
  config :zebra, domain: System.get_env("BASE_DOMAIN")
  config :zebra, Zebra.Machines.Brownout,
    excluded_organization_ids: System.get_env("BROWNOUT_EXCLUDED_ORGANIZATION_IDS") || ""

  config :zebra, artifacthub_api_endpoint: System.fetch_env!("INTERNAL_API_URL_ARTIFACTHUB")
  config :zebra, cachehub_api_endpoint: System.fetch_env!("INTERNAL_API_URL_CACHEHUB")
  config :zebra, chmura_endpoint: System.fetch_env!("INTERNAL_API_URL_CHMURA")
  config :zebra, dt_api_endpoint: System.fetch_env!("INTERNAL_API_URL_GOFER")
  config :zebra, feature_api_endpoint: System.fetch_env!("INTERNAL_API_URL_FEATURE")
  config :zebra, loghub2_api_endpoint: System.fetch_env!("INTERNAL_API_URL_LOGHUB2")
  config :zebra, organization_api_endpoint: System.fetch_env!("INTERNAL_API_URL_ORGANIZATION")
  config :zebra, projecthub_api_endpoint: System.fetch_env!("INTERNAL_API_URL_PROJECT")
  config :zebra, rbac_endpoint: System.fetch_env!("INTERNAL_API_URL_RBAC")
  config :zebra, repo_proxy_api_endpoint: System.fetch_env!("INTERNAL_API_URL_REPO_PROXY")
  config :zebra, repository_api_endpoint: System.fetch_env!("INTERNAL_API_URL_REPOSITORY")
  config :zebra, secrethub_api_endpoint: System.fetch_env!("INTERNAL_API_URL_SECRETHUB") # sobelow_skip ["Config.Secrets"]
  config :zebra, self_hosted_agents_grpc_endpoint: System.fetch_env!("INTERNAL_API_URL_AGENTHUB")
end
