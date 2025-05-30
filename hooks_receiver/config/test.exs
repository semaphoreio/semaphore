import Config

config :hooks_receiver,
  repository_api_grpc: "localhost:50051",
  organization_api_grpc: "localhost:50051"

config :junit_formatter,
  automatic_create_dir?: true,
  report_dir: "./out",
  report_file: "test-reports.xml",
  print_report_file: true,
  include_filename?: true,
  include_file_line?: true
