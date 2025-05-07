# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :canvas_front,
  generators: [timestamp_type: :utc_datetime],
  delivery_grpc_endpoint: "127.0.0.1:50051",
  organization_api_grpc_endpoint: "127.0.0.1:50051",
  permission_patrol_grpc_endpoint: "127.0.0.1:50051",
  rbac_grpc_endpoint: "127.0.0.1:50051",
  feature_grpc_endpoint: "127.0.0.1:50051",
  guard_user_grpc_endpoint: "127.0.0.1:50051"

config :canvas_front,
  guard_grpc_timeout: 5000,
  permission_patrol_timeout: 5000,
  use_rbac_api: true

# Configures the endpoint
config :canvas_front, CanvasFrontWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: CanvasFrontWeb.ErrorHTML, json: CanvasFrontWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: CanvasFront.PubSub,
  live_view: [signing_salt: "i2+QxKLi"]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

config :sentry, client: CanvasFront.SentryFinchHTTPClient

config :canvas_front, :environment, config_env()

if System.get_env("AMQP_URL") != nil do
  config :amqp,
    connections: [
      amqp: [
        url: System.get_env("AMQP_URL"),
        name: "#{System.get_env("HOSTNAME", "canvas_front")}"
      ]
    ],
    channels: []
end

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
