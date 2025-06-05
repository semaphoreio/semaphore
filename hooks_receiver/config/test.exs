import Config

config :hooks_receiver,
  repository_api_grpc: "localhost:50051",
  organization_api_grpc: "localhost:50051",
  license_checker_grpc: "localhost:50051"

config :junit_formatter,
  report_dir: "./out",
  report_file: "results.xml",
  print_report_file: true,
  include_filename?: true,
  include_file_line?: true
