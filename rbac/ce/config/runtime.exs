import Config

config :watchman,
  host: "0.0.0.0",
  port: 8125,
  prefix: "rbac-ce.#{System.get_env("METRICS_NAMESPACE") || "dev"}"

config :rbac, Rbac.Repo,
  adapter: Ecto.Adapters.Postgres,
  prepare: :unnamed,
  database: System.get_env("POSTGRES_DB_NAME") || "rbac_ce",
  username: System.get_env("POSTGRES_DB_USER") || "postgres",
  password: System.get_env("POSTGRES_DB_PASSWORD") || "the-cake-is-a-lie",
  hostname: System.get_env("POSTGRES_DB_HOST") || "127.0.0.1",
  pool_size: String.to_integer(System.get_env("POSTGRES_DB_POOL_SIZE") || "1"),
  parameters: [application_name: "rbac"],
  migration_primary_key: [name: :id, type: :binary_id],
  ssl: System.get_env("POSTGRES_DB_SSL") == "true" || false,
  ssl_opts: [
    verify: :verify_none
  ],
  migration_timestamps: [
    type: :naive_datetime,
    inserted_at: :created_at,
    updated_at: :updated_at
  ]

config :rbac,
  user_api_grpc_endpoint: System.get_env("INTERNAL_API_URL_USER") || "localhost:50052",
  projecthub_grpc_endpoint: System.get_env("INTERNAL_API_URL_PROJECT") || "localhost:50052",
  organization_grpc_endpoint: System.get_env("INTERNAL_API_URL_ORGANIZATION") || "localhost:50052"

config :rbac, amqp_url: System.get_env("AMQP_URL") || "amqp://127.0.0.1:5672"

if System.get_env("AMQP_URL") != nil do
  config :amqp,
    connections: [
      amqp: [url: System.get_env("AMQP_URL")]
    ],
    channels: [
      authorization: [connection: :amqp]
    ]
end
