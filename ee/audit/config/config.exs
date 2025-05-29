import Config

config :audit, :environment, config_env()

config :grpc, start_server: true

config :logger, :console,
  level: :info,
  truncate: 16096,
  format: "\n$time $metadata[$level] $message",
  metadata: [:module, :job_id, :ctx],
  handle_otp_reports: true,
  handle_sasl_reports: true

if config_env() == :test do
  config :audit, Audit.Repo, pool: Ecto.Adapters.SQL.Sandbox

  config :junit_formatter,
    automatic_create_dir?: true,
    report_dir: "./out",
    report_file: "test-reports.xml",
    print_report_file: true,
    include_filename?: true,
    include_file_line?: true
end

config :audit, ecto_repos: [Audit.Repo]

config :ex_aws,
  json_codec: Poison
