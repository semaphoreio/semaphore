import Config

if config_env() == :prod do
  config :hooks_receiver,
    repository_api_grpc: System.fetch_env!("INTERNAL_API_URL_REPOSITORY"),
    organization_api_grpc: System.fetch_env!("INTERNAL_API_URL_ORGANIZATION")
end
