import Config

import_config "_silent_lager.exs"

config :watchman,
  host: "0.0.0.0",
  port: 8125,
  prefix: "projecthub.#{System.get_env("METRICS_NAMESPACE") || "dev"}"

config :logger, :console,
  format: "$level$levelpad[$metadata] $message\n",
  metadata: [:request_id]

config :logger,
  level: :debug

config :grpc, start_server: true

config :projecthub, Projecthub.Repo,
  adapter: Ecto.Adapters.Postgres,
  migration_primary_key: [id: :uuid, type: :binary_id],
  parameters: [application_name: "projecthub"]

config :projecthub, amqp_url: System.get_env("AMQP_URL")

config :projecthub,
  start_project_init_worker?: System.get_env("START_PROJECT_INIT_WORKER"),
  start_internal_api?: System.get_env("START_INTERNAL_API"),
  start_project_cleaner?: System.get_env("START_PROJECT_CLEANER")

config :projecthub,
  ecto_repos: [Projecthub.Repo],
  user_grpc_endpoint: "127.0.0.1:50051",
  organization_grpc_endpoint: "127.0.0.1:50051",
  artifacthub_grpc_endpoint: "127.0.0.1:50051",
  cache_grpc_endpoint: "127.0.0.1:50051",
  rbac_grpc_endpoint: "127.0.0.1:50051",
  periodic_scheduler_grpc_endpoint: "127.0.0.1:50051",
  repohub_grpc_endpoint: "127.0.0.1:50051",
  repositoryhub_grpc_endpoint: "127.0.0.1:50051",
  feature_grpc_endpoint: "127.0.0.1:50051",
  grpc_port: 50_051,
  grpc_stubs: [
    Support.FakeServices.UserService,
    Support.FakeServices.OrganizationService,
    Support.FakeServices.ArtifactService,
    Support.FakeServices.CacheService,
    Support.FakeServices.RbacService,
    Support.FakeServices.PeriodicSchedulerService,
    Support.FakeServices.RepositoryService,
    Support.FakeServices.RepositoryIntegratorService,
    Support.FakeServices.FeatureService
  ]

config :projecthub, Projecthub.Workers.ProjectCleaner,
  jobs: [
    # Every Midnight
    {"0 0 * * *", {Projecthub.Workers.ProjectCleaner, :process, []}}
  ]

config :projecthub, :hard_destroy_grace_period_days, 30

import_config "#{config_env()}.exs"
