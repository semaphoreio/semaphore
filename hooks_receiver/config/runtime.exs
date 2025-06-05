import Config

if config_env() == :prod do
  config :hooks_receiver,
    repository_api_grpc: System.fetch_env!("INTERNAL_API_URL_REPOSITORY"),
    organization_api_grpc: System.fetch_env!("INTERNAL_API_URL_ORGANIZATION"),
    license_checker_grpc:
      System.get_env("INTERNAL_API_URL_LICENSE_CHECKER", "license-checker:50051"),
    edition: System.get_env("EDITION", "") |> String.trim() |> String.downcase()
end
