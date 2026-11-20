import Config

config :dashboardhub,
  amqp_url: System.get_env("AMQP_URL")

config :dashboardhub, Dashboardhub.Repo,
  prepare: :unnamed,
  database: System.get_env("POSTGRES_DB_NAME"),
  username: System.get_env("POSTGRES_DB_USER"),
  password: System.get_env("POSTGRES_DB_PASSWORD"),
  hostname: System.get_env("POSTGRES_DB_HOST"),
  pool_size: String.to_integer(System.get_env("POSTGRES_DB_POOL_SIZE")),
  ssl: System.get_env("POSTGRES_DB_SSL") == "true" || false,
  ssl_opts: [
    verify: :verify_none
  ]

config :logger, level: String.to_atom(System.get_env("LOG_LEVEL"))

config :sentry,
  dsn: System.get_env("SENTRY_DSN"),
  tags: %{
    application: System.get_env("SENTRY_APPLICATION")
  },
  environment_name: System.get_env("SENTRY_ENV")

config :watchman,
  host: "0.0.0.0",
  port: 8125,
  prefix: "dashboardhub.#{System.get_env("METRICS_NAMESPACE") || "dev"}"

if System.get_env("AMQP_URL") != nil do
  config :amqp,
    connections: [
      amqp: [
        url: System.get_env("AMQP_URL"),
        name: "#{System.get_env("HOSTNAME", "dashboardhub")}"
      ]
    ],
    channels: [
      dashboardhub: [connection: :amqp]
    ]
end

config :dashboardhub, :migrations_path, System.get_env("MIGRATIONS_PATH") || "/app/migrations"
