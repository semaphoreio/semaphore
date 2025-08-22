# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.
import Config

config :phoenix, :json_library, Poison

# Configures the endpoint
config :front, FrontWeb.Endpoint,
  url: [host: "localhost"],
  http: [protocol_options: [max_request_line_length: 8192, max_header_value_length: 8192]],
  secret_key_base: System.get_env("SECRET_KEY_BASE"),
  render_errors: [view: FrontWeb.ErrorView, accepts: ~w(html json)],
  pubsub_server: Front.PubSub

config :front, :signing_salt, System.get_env("SESSION_SIGNING_SALT")

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:user_id]

config :logger, level: (System.get_env("LOG_LEVEL") || "debug") |> String.to_atom()

config :front,
  default_internal_api_request_timeout: 30_000

config :front, default_user_name: "Semaphore User"

config :feature_provider, provider: {Front.FeatureHubProvider, []}
config :front, :superjerry_client, {Support.FakeClients.Superjerry, []}
config :front, :scouter_client, {Front.Clients.Scouter, []}
config :front, :service_account_client, {Support.FakeClients.ServiceAccount, []}

config :money,
  default_currency: :USD,
  separator: ",",
  delimeter: ".",
  symbol: true,
  symbol_on_right: false,
  symbol_space: false

if System.get_env("AMQP_URL") != nil do
  config :amqp,
    connections: [
      amqp: [url: System.get_env("AMQP_URL")]
    ],
    channels: [
      audit: [connection: :amqp]
    ]
end

config :front, :userpilot_token, ""

config :front, :get_started_path, "priv/onboarding/getting_started.yaml"
config :front, :workflow_templates_path, "workflow_templates/saas"
config :front, :new_project_onboarding_workflow_templates_path, "workflow_templates/saas_new"

import_config "#{Mix.env()}.exs"
