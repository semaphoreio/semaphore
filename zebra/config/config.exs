import Config

config :zebra, :environment, config_env()
config :zebra, rbac_timeout: 30_000

config :zebra,
  ecto_repos: [Zebra.LegacyRepo]

config :zebra, Zebra.LegacyRepo,
  migration_primary_key: [id: :uuid, type: :binary_id]

config :grpc, start_server: true

# Configures Elixir's Logger
config :logger, :console,
  level: :info,
  truncate: 16096,
  format: "$time $metadata[$level] $message\n",
  metadata: [:module, :job_id],
  handle_otp_reports: true,
  handle_sasl_reports: true

config :zebra, Zebra.Workers.TaskFinisher, timeout: 10_000
config :zebra, Zebra.Workers.Dispatcher, timeout: 1_000
config :zebra, Zebra.Workers.Monitor, timeout: 60_000

config :zebra, Zebra.Workers.JobDeletionPolicyWorker,
  naptime: 28_800_000, # 8 hours
  days: 490,
  limit: 5,
  deletion_delay: 1_000 # 1 second

config :zebra, Zebra.Workers.Scheduler,
  cooldown_period: 1_000,
  batch_size: 3

config :zebra, domain: "semaphore.#{Atom.to_string(config_env())}"

config :zebra, artifacthub_api_endpoint: "localhost:50051"
config :zebra, cachehub_api_endpoint: "localhost:50051"
config :zebra, chmura_endpoint: "localhost:50051"
config :zebra, dt_api_endpoint: "localhost:50051"
config :zebra, feature_api_endpoint: "localhost:50051"
config :zebra, loghub2_api_endpoint: "localhost:50051"
config :zebra, organization_api_endpoint: "localhost:50051"
config :zebra, projecthub_api_endpoint: "localhost:50051"
config :zebra, rbac_endpoint: "localhost:50051"
config :zebra, repo_proxy_api_endpoint: "localhost:50051"
config :zebra, repository_api_endpoint: "localhost:50051"
config :zebra, secrethub_api_endpoint: "localhost:50051" # sobelow_skip ["Config.Secrets"]
config :zebra, self_hosted_agents_grpc_endpoint: "localhost:50051"

import_config "#{config_env()}.exs"
