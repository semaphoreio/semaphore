import Config

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.
# The block below contains prod specific runtime configuration.

get_env! = &(System.get_env(&1) || raise("env variable #{&1} is missing"))

get_integer = fn env_var, default ->
  case System.get_env(env_var) do
    nil -> default
    value -> String.to_integer(value)
  end
end

if config_env() == :prod do
  config :gofer, amqp_url: System.get_env("AMQP_URL") || "amqp://rabbitmq:5672"

  config :gofer, Gofer.EctoRepo,
    hostname: get_env!.("DB_HOSTNAME"),
    username: get_env!.("DB_USERNAME"),
    password: get_env!.("DB_PASSWORD"),
    database: "gofer_repo",
    parameters: [application_name: "gofer"],
    ssl: System.get_env("POSTGRES_DB_SSL") == "true"

  config :watchman,
    host: "localhost",
    port: 8125,
    prefix: "gofer.#{System.get_env("METRICS_NAMESPACE") || "env-missing"}"

  config :gofer,
    plumber_grpc_url: get_env!.("PLUMBER_URL"),
    start_grpc?: get_env!.("START_GRPC") == "true",
    start_cache?: get_env!.("START_CACHE") == "true",
    start_engines?: get_env!.("START_ENGINES") == "true",
    start_metrics?: get_env!.("START_METRICS") == "true",
    target_trigger_ttl_ms:
      get_integer.("TARGET_TRIGGER_TTL_MS", Application.get_env(:gofer, :target_trigger_ttl_ms)),
    target_trigger_queue_limit:
      get_integer.(
        "TARGET_TRIGGER_QUEUE_LIMIT",
        Application.get_env(:gofer, :target_trigger_queue_limit)
      )

  config :gofer, Gofer.RBAC.RolesCache,
    cache_name: :rbac_roles,
    enabled?: get_env!.("ROLES_CACHE_ENABLED") == "true",
    expiration_ttl: get_env!.("ROLES_CACHE_EXPIRATION_TTL") |> String.to_integer(),
    expiration_interval: get_env!.("ROLES_CACHE_EXPIRATION_INTERVAL") |> String.to_integer(),
    size_limit: get_env!.("ROLES_CACHE_SIZE_LIMIT") |> String.to_integer(),
    reclaim_coef: get_env!.("ROLES_CACHE_RECLAIM_COEF") |> String.to_float()

  config :gofer, Gofer.RBAC.Client, endpoint: get_env!.("INTERNAL_API_URL_RBAC")
  config :gofer, Gofer.SecrethubClient, endpoint: get_env!.("INTERNAL_API_URL_SECRETHUB")

  if log_level = System.get_env("LOG_LEVEL") do
    config :logger, level: String.to_existing_atom(log_level)
  end
end
