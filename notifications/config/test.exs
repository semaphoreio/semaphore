import Config

config :junit_formatter,
  automatic_create_dir?: true,
  report_dir: "./out",
  report_file: "test-reports.xml",
  print_report_file: true,
  include_filename?: true,
  include_file_line?: true

config :notifications, rbac_endpoint: "localhost:50052"
config :notifications, secrethub_endpoint: "localhost:50052" # sobelow_skip ["Config.Secrets"]
config :notifications, pipeline_endpoint: "localhost:50052" # sobelow_skip ["Config.Secrets"]
config :notifications, projecthub_endpoint: "localhost:50052" # sobelow_skip ["Config.Secrets"]
config :notifications, repo_proxy_endpoint: "localhost:50052" # sobelow_skip ["Config.Secrets"]
config :notifications, workflow_endpoint: "localhost:50052" # sobelow_skip ["Config.Secrets"]
config :notifications, organization_endpoint: "localhost:50052" # sobelow_skip ["Config.Secrets"]

config :notifications, Notifications.Repo, pool: Ecto.Adapters.SQL.Sandbox
