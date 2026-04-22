import Config

config :logger, level: (System.get_env("LOG_LEVEL") || "debug") |> String.to_atom()

config :rbac, Rbac.Repo,
  adapter: Ecto.Adapters.Postgres,
  database: System.get_env("POSTGRES_DB_NAME") || "guard",
  username: System.get_env("POSTGRES_DB_USER") || "postgres",
  password: System.get_env("POSTGRES_DB_PASSWORD") || "the-cake-is-a-lie",
  hostname: System.get_env("POSTGRES_DB_HOST") || "127.0.0.1",
  pool_size: String.to_integer(System.get_env("POSTGRES_DB_POOL_SIZE") || "1"),
  parameters: [application_name: "rbac"],
  migration_primary_key: [name: :id, type: :binary_id],
  ssl: System.get_env("POSTGRES_DB_SSL") == "true" || false,
  ssl_opts: [verify: :verify_none],
  migration_timestamps: [
    type: :naive_datetime,
    inserted_at: :inserted_at,
    updated_at: :updated_at
  ]

config :rbac, Rbac.FrontRepo,
  adapter: Ecto.Adapters.Postgres,
  database: System.get_env("POSTGRES_FRONT_DB_NAME") || "front",
  username: System.get_env("POSTGRES_DB_USER") || "postgres",
  password: System.get_env("POSTGRES_DB_PASSWORD") || "the-cake-is-a-lie",
  hostname: System.get_env("POSTGRES_DB_HOST") || "127.0.0.1",
  pool_size: String.to_integer(System.get_env("POSTGRES_DB_POOL_SIZE") || "1"),
  ssl: System.get_env("POSTGRES_DB_SSL") == "true" || false,
  ssl_opts: [verify: :verify_none]

config :rbac,
  projecthub_grpc_endpoint: System.fetch_env!("INTERNAL_API_URL_PROJECT"),
  repositoryhub_grpc_endpoint: System.fetch_env!("INTERNAL_API_URL_REPOSITORY"),
  organization_grpc_endpoint: System.fetch_env!("INTERNAL_API_URL_ORGANIZATION")

config :rbac, amqp_url: System.get_env("AMQP_URL") || "amqp://127.0.0.1:5672"

if System.get_env("AMQP_URL") != nil do
  config :amqp,
    connections: [
      amqp: [
        url: System.get_env("AMQP_URL"),
        name: "#{System.get_env("HOSTNAME", "rbac")}"
      ]
    ],
    channels: [
      audit: [connection: :amqp],
      authorization: [connection: :amqp],
      user: [connection: :amqp]
    ]
end

config :rbac,
  oidc: [
    discovery_url: System.get_env("OIDC_DISCOVERY_URL"),
    client_id: System.get_env("OIDC_CLIENT_ID"),
    client_secret: System.get_env("OIDC_CLIENT_SECRET"),
    manage_url: System.get_env("OIDC_MANAGE_URL"),
    manage_client_id: System.get_env("OIDC_MANAGE_CLIENT_ID"),
    manage_client_secret: System.get_env("OIDC_MANAGE_CLIENT_SECRET")
  ]

config :rbac, on_prem: System.get_env("ON_PREM") == "true"

config :rbac, base_domain: System.get_env("BASE_DOMAIN")
config :rbac, session_secret_key_base: System.get_env("SESSION_SECRET_KEY_BASE")
config :rbac, session_key: System.get_env("SESSION_COOKIE_NAME")

config :rbac,
  okta_session_expiration_default_minutes:
    String.to_integer(System.get_env("OKTA_SESSION_EXPIRATION_DEFAULT_MINUTES") || "20160"),
  okta_session_expiration_max_minutes:
    String.to_integer(System.get_env("OKTA_SESSION_EXPIRATION_MAX_MINUTES") || "43200")

config :rbac, ignore_refresh_requests: System.get_env("IGNORE_REFRESH_REQUESTS") == "true"
