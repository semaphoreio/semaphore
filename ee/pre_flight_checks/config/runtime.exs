import Config

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.
# The block below contains prod specific runtime configuration.

if config_env() == :prod do
  config :pre_flight_checks, PreFlightChecks.EctoRepo,
    prepare: :unnamed,
    hostname: System.get_env("DB_HOSTNAME") || raise("env variable DB_HOSTNAME is missing"),
    username: System.get_env("DB_USERNAME") || raise("env variable DB_USERNAME is missing"),
    password: System.get_env("DB_PASSWORD") || raise("env variable DB_PASSWORD is missing"),
    database: "pre_flight_checks",
    ssl: System.get_env("POSTGRES_DB_SSL") == "true"

  config :pre_flight_checks,
    amqp_url: System.get_env("AMQP_URL") || raise("env variable AMQP_URL is missing")

  config :watchman,
    host: "localhost",
    port: 8125,
    prefix: "pre_flight_checks.#{System.get_env("METRICS_NAMESPACE") || "env-missing"}"
end
