import Config

config :junit_formatter,
  report_dir: "",
  report_file: "junit.xml",
  print_report_file: true,
  include_filename?: true,
  include_file_line?: true

config :secrethub, Secrethub.Repo, pool: Ecto.Adapters.SQL.Sandbox
