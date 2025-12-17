import Config

config :auth, trusted_proxies: ["127.0.0.1"] |> Enum.filter(& &1) |> Enum.filter(& &1 != "")

# Disable JWKS fetching in tests (no Keycloak available)
config :auth, jwks_enabled: false

config :junit_formatter,
  automatic_create_dir?: true,
  report_dir: "./out",
  report_file: "test-reports.xml",
  print_report_file: true,
  include_filename?: true,
  include_file_line?: true
