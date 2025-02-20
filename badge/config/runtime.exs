import Config

config :watchman,
  host: "0.0.0.0",
  port: 8125,
  prefix: "badges.#{System.get_env("METRICS_NAMESPACE") || "dev"}"

config :badges, http_port: 4000

if config_env() == :prod do
  config :badges, projecthub_grpc_endpoint: System.fetch_env!("INTERNAL_API_URL_PROJECT")
  config :badges, plumber_grpc_endpoint: System.fetch_env!("INTERNAL_API_URL_PLUMBER")
end

config :sentry,
  dsn: System.get_env("SENTRY_DSN"),
  environment_name: config_env(),
  enable_source_code_context: true,
  root_source_code_path: File.cwd!(),
  included_environments: [:prod]
