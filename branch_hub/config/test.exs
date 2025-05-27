use Mix.Config

config :junit_formatter,
automatic_create_dir?: true,
  report_dir: ".",
  report_file: "test-reports.xml",
  print_report_file: true,
  include_filename?: true,
  include_file_line?: true

config :branch_hub, BranchHub.Repo, pool: Ecto.Adapters.SQL.Sandbox
