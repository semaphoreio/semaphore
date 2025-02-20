import Config

config :rbac, :migrations_path, System.get_env("MIGRATIONS_PATH") || "/app/migrations"

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:user_id]

config :rbac, environment: :prod
