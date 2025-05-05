import Config

config :front, :environment, :test

config :front, FrontWeb.Endpoint,
  url: [host: "localhost"],
  http: [port: 4001],
  server: true

config :logger, :console,
  level: :info,
  format: {Support.Logger, :format},
  metadata: [:file, :line, :inspect]

config :front,
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
  usage_grpc_endpoint: "127.0.0.1:50052",
  user_grpc_endpoint: "127.0.0.1:50052",
  velocity_grpc_endpoint: "127.0.0.1:50052",
  workflow_api_grpc_endpoint: "127.0.0.1:50052",
  jwt_grpc_endpoint: "127.0.0.1:50052"

config :front,
  domain: "semaphoretest.test",
  docs_domain: "docs.semaphoretest.test",
  start_reactor: true

config :wallaby, screenshot_dir: System.get_env("WALLABY_SCREENSHOTS") || "./out"
config :wallaby, screenshot_on_failure: true
config :wallaby, driver: Wallaby.Experimental.Chrome
config :wallaby, max_wait_time: 10_000

config :joken, current_time_adapter: Support.TimeMock

config :front, guard_grpc_timeout: 1_000
config :front, permission_patrol_timeout: 1_000

config :junit_formatter,
  report_file: "test-ex-junit-report.xml",
  report_dir: System.get_env("REPORT_PATH") || "./out",
  automatic_create_dir?: true,
  print_report_file: true,
  prepend_project_name?: false,
  include_filename?: true

config :front, me_host: "me.", me_path: "/"
config :front, :artifact_host, "http://localhost:9000"
