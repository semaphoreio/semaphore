import Config

config :projecthub, environment: :test

config :projecthub, Projecthub.Repo, pool: Ecto.Adapters.SQL.Sandbox

config :exvcr,
  vcr_cassette_library_dir: "test/fixture/vcr_cassettes",
  filter_sensitive_data: [
    [pattern: "token [^\"]+", placeholder: "token yourtokencomeshere"]
  ]

config :junit_formatter,
  automatic_create_dir?: true,
  report_dir: "./out",
  report_file: "test-reports.xml",
  print_report_file: true,
  include_filename?: true,
  include_file_line?: true
