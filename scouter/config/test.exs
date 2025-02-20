import Config

config :scouter, Scouter.Repo, pool: Ecto.Adapters.SQL.Sandbox

config :junit_formatter,
  report_dir: "./out",
  report_file: "results.xml",
  automatic_create_dir?: true,
  print_report_file: true,
  prepend_project_name?: false,
  include_filename?: true
