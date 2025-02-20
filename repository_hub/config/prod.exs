import Config

config :repository_hub, environment: :prod

config :repository_hub, grpc_stubs: []

config :tesla, adapter: Tesla.Adapter.Hackney
