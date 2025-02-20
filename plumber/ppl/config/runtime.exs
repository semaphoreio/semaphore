import Config

config :ppl, Ppl.EctoRepo,
  database: System.get_env("POSTGRES_DB_NAME"),
  username: System.get_env("POSTGRES_DB_USER"),
  password: System.get_env("POSTGRES_DB_PASSWORD"),
  hostname: System.get_env("POSTGRES_DB_HOST"),
  pool_size: String.to_integer(System.get_env("POSTGRES_DB_POOL_SIZE") || "1"),
  ssl: System.get_env("POSTGRES_DB_SSL") == "true" || false

# Encryption module config
config :cloak, Cloak.AES.GCM,
  default: true,
  tag: "GCM",
  keys: [
    %{tag: <<1>>, key: {:system, "USER_CREDS_ENC_KEY_1"}, default: true}
  ]

config :block, Block.EctoRepo,
  database: System.get_env("BLOCK_POSTGRES_DB_NAME"),
  username: System.get_env("BLOCK_POSTGRES_DB_USER"),
  password: System.get_env("BLOCK_POSTGRES_DB_PASSWORD"),
  hostname: System.get_env("BLOCK_POSTGRES_DB_HOST"),
  pool_size: String.to_integer(System.get_env("BLOCK_POSTGRES_DB_POOL_SIZE") || "1"),
  ssl: System.get_env("BLOCK_POSTGRES_DB_SSL") == "true" || false

{metric_channel, metrics_format} =
  System.get_env("ON_PREM")
  |> case do
    "true" -> {:external, :aws_cloudwatch}
    _ -> {:internal, :statsd_graphite}
  end

config :watchman,
  host: System.get_env("METRICS_HOST") || "0.0.0.0",
  port: (System.get_env("METRICS_PORT") || "8125") |> Integer.parse() |> elem(0),
  send_only: metric_channel,
  external_backend: metrics_format,
  prefix:
    System.get_env("METRICS_PREFIX") || "ppl.#{System.get_env("METRICS_NAMESPACE") || "dev"}"
