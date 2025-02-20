import Config

config :dashboardhub, grpc_port: 50_051

config :dashboardhub, ecto_repos: [Dashboardhub.Repo]

config :dashboardhub, Dashboardhub.Repo,
  adapter: Ecto.Adapters.Postgres,
  parameters: [application_name: "dashboardhub"],
  loggers: [
    {Ecto.LogEntry, :log, [:debug]}
  ]

if System.get_env("AMQP_URL") != nil do
  config :amqp,
    connections: [
      amqp: [url: System.get_env("AMQP_URL")]
    ],
    channels: [
      dashboardhub: [connection: :amqp]
    ]
end

import_config "#{config_env()}.exs"
