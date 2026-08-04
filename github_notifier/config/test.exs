import Config

config :github_notifier, environment: :test

config :github_notifier, status_guard_busy_budget_ms: 250

config :logger, level: :debug

config :junit_formatter,
  automatic_create_dir?: true,
  report_dir: "./out",
  report_file: "test-reports.xml",
  print_report_file: true,
  include_filename?: true,
  include_file_line?: true
