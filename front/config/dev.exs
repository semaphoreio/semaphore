import Config

config :front, :environment, :dev

config :front, FrontWeb.Endpoint,
  http: [port: 4000],
  debug_errors: true,
  code_reloader: true,
  check_origin: false,
  watchers: [
    node: [
      "build.js",
      cd: Path.expand("../assets", __DIR__),
      env: %{"ESBUILD_LOG_LEVEL" => "silent", "ESBUILD_WATCH" => "1"}
    ]
  ],
  live_reload: [
    patterns: [
      ~r{priv/static/assets/.*(js|css)$},
      ~r{priv/static/assets/.*(png|jpeg|jpg|gif|svg)$},
      ~r{lib/front_web/views/.*(ex)$},
      ~r{lib/front_web/templates/.*(eex)$},
      ~r{assets/js/.*(ts|tsx|js)$}
    ]
  ]

# Do not include metadata nor timestamps in development logs
config :logger, :console, format: "[$level] $message\n"

config :phoenix, :stacktrace_depth, 20

config :front,
  cookie_name: "_semaphoreappdotcom_dev_session",
  # API endpoints
  artifacthub_api_grpc_endpoint: "127.0.0.1:50052",
  audit_grpc_endpoint: "127.0.0.1:50052",
  authentication_grpc_endpoint: "127.0.0.1:50051",
  billing_api_grpc_endpoint: "127.0.0.1:50052",
  branch_api_grpc_endpoint: "127.0.0.1:50052",
  dashboard_api_grpc_endpoint: "127.0.0.1:50052",
  feature_grpc_endpoint: "127.0.0.1:50052",
  gofer_grpc_endpoint: "127.0.0.1:50052",
  guard_grpc_endpoint: "127.0.0.1:50052",
  guard_user_grpc_endpoint: "127.0.0.1:50052",
  instance_config_grpc_endpoint: "127.0.0.1:50052",
  job_api_grpc_endpoint: "127.0.0.1:50052",
  loghub2_api_grpc_endpoint: "127.0.0.1:50051",
  loghub_api_grpc_endpoint: "127.0.0.1:50051",
  notification_api_grpc_endpoint: "127.0.0.1:50052",
  okta_grpc_endpoint: "127.0.0.1:50052",
  organization_api_grpc_endpoint: "127.0.0.1:50052",
  periodic_scheduler_grpc_endpoint: "127.0.0.1:50052",
  permission_patrol_grpc_endpoint: "127.0.0.1:50052",
  pipeline_api_grpc_endpoint: "127.0.0.1:50052",
  ppl_grpc_endpoint: "127.0.0.1:50051",
  pre_flight_checks_grpc_endpoint: "127.0.0.1:50052",
  projecthub_grpc_endpoint: "127.0.0.1:50052",
  rbac_grpc_endpoint: "127.0.0.1:50052",
  groups_grpc_endpoint: "127.0.0.1:50052",
  repo_proxy_grpc_endpoint: "127.0.0.1:50051",
  repohub_grpc_endpoint: "127.0.0.1:50052",
  repository_integrator_grpc_endpoint: "127.0.0.1:50052",
  repositoryhub_grpc_endpoint: "127.0.0.1:50052",
  scouter_grpc_endpoint: "127.0.0.1:50052",
  secrets_api_grpc_endpoint: "127.0.0.1:50052",
  self_hosted_agents_grpc_endpoint: "127.0.0.1:50052",
  superjerry_grpc_endpoint: "127.0.0.1:50051",
  task_grpc_endpoint: "127.0.0.1:50052",
  velocity_grpc_endpoint: "127.0.0.1:50052",
  workflow_api_grpc_endpoint: "127.0.0.1:50052",
  jwt_grpc_endpoint: "127.0.0.1:50052",
  license_grpc_endpoint: "127.0.0.1:50052"

config :front, domain: "semaphoredev.dev"
config :front, me_host: nil, me_path: "/me"
config :front, docs_domain: "docs.semaphoredev.dev"
config :front, guard_grpc_timeout: 1_000
config :front, permission_patrol_timeout: 1_000
config :front, :connect_github_app_url, "http://localhost:4004/github_app_manifest"

# Support Client tokens
config :front,
  support_app_id: "du8TzC9z2pBIrojNZo10I232e5vsD69O",
  support_app_secret: "d27Yd4IrbHcJ1jmz1QDrGjx3ji7COoJq"

config :front, :artifact_host, "http://localhost:9000"
