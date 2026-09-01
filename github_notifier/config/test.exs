import Config

config :github_notifier, environment: :test

# Keep the fetch-timeout tests fast and deterministic.
config :github_notifier, fetch_timeout: 200

config :logger, level: :debug

config :junit_formatter,
  automatic_create_dir?: true,
  report_dir: "./out",
  report_file: "test-reports.xml",
  print_report_file: true,
  include_filename?: true,
  include_file_line?: true
