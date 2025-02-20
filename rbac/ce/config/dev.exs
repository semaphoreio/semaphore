import Config

config :rbac, environment: :dev

config :rbac,
  user_api_grpc_endpoint: "localhost:50052",
  projecthub_grpc_endpoint: "localhost:50052",
  organization_grpc_endpoint: "localhost:50052"
