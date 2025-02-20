import Config

config :auth, trusted_proxies: ["127.0.0.1"] |> Enum.filter(& &1) |> Enum.filter(& &1 != "")

config :junit_formatter,
  report_dir: "./out",
  report_file: "results.xml",
  # Adds information about file location when suite finishes
  print_report_file: true,
  # Include filename and file number for more insights
  include_filename?: true,
  include_file_line?: true
