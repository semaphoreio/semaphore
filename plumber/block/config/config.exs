import Config

config :block,
  ecto_repos: [Block.EctoRepo]

config :block, Block.EctoRepo,
  adapter: Ecto.Adapters.Postgres,
  database: System.get_env("BLOCK_POSTGRES_DB_NAME"),
  username: System.get_env("BLOCK_POSTGRES_DB_USER"),
  password: System.get_env("BLOCK_POSTGRES_DB_PASSWORD"),
  hostname: System.get_env("BLOCK_POSTGRES_DB_HOST"),
  pool_size: String.to_integer(System.get_env("BLOCK_POSTGRES_DB_POOL_SIZE") || "1"),
  ssl: System.get_env("BLOCK_POSTGRES_DB_SSL") == "true" || false,
  parameters: [application_name: "plumber-block"]

config :grpc, http2_client_adapter: GRPC.Adapter.Gun

config :watchman,
    host: System.get_env("METRICS_HOST") || "statsd",
    port: (System.get_env("METRICS_PORT") || "8125") |> Integer.parse() |> elem(0),
    external_only: System.get_env("METRICS_HOST") != "",
    prefix: "block.k8s-staging"

# Number of log lines per second
config :logger, :console, max_buffer: 100

# Mappings to function definitions for functions available in when condition DSL
config :when, change_in: {Block.ChangeInResolver, :change_in, [1, 2]}

# Time to wait bere block status is reexamined
config :block, general_looper_cooling_time_sec: 1
# Specific cooling time values for each looper, uncomment to override general one
# config :block, blk_initializing_ct: 1
# config :block, blk_running_ct: 1
# config :block, blk_stopping_ct: 1
# config :block, task_pending_ct: 1
# config :block, task_running_ct: 1
# config :block, task_stopping_ct: 1

# Time period looper will sleep between scheduling in miliseconds
config :block, general_sleeping_period_ms: 1000
# Specific Time period values for each looper, uncomment to override general one
# config :block, blk_initializing_sp: 1000
# config :block, blk_running_sp: 1000
# config :block, blk_stopping_sp: 1000
# config :block, task_pending_sp: 1000
# config :block, task_running_sp: 1000
# config :block, task_stopping_sp: 1000

# Sleep period for StateWatch loopers
config :block, state_watch_sleep_period_ms: 30_000
# Sleep period for StateResidency loopers
config :block, state_residency_sleep_period_ms: 20_000

# Interval between two Beholder execution
config :block, beholder_blk_sleep_period_sec: 3
# Interval after which stuck block build is moved out of scheduling state
config :block, beholder_blk_threshold_sec: 10
# Stuck block build can be recovered at most n times
config :block, beholder_blk_threshold_count: 5

# Interval between two Beholder execution
config :block, beholder_task_sleep_period_sec: 3
# Interval after which stuck block is moved out of scheduling state
config :block, beholder_task_threshold_sec: 10
#Stuck block can be recovered at most n times
config :block, beholder_task_threshold_count: 5

config :block, block_done_notification_callback: {IO, :inspect}
config :block, compile_task_done_notification_callback: {IO, :inspect}
config :block, after_ppl_task_done_notification_callback: {IO, :inspect}

# Encryption module config
config :cloak, Cloak.AES.GCM,
  default: true,
  tag: "GCM",
  keys: [
    %{tag: <<1>>, key: {:system, "USER_CREDS_ENC_KEY_1"}, default: true}
  ]


# disable logging of ecto queries
config :logger, level: :info
# for debugging queries
# config :logger, level: :debug


# This configuration is loaded before any dependency and is restricted
# to this project. If another project depends on this project, this
# file won't be loaded nor affect the parent project. For this reason,
# if you want to provide default values for your application for
# 3rd-party users, it should be done in your "mix.exs" file.

# You can configure your application as:
#
#     config :block, key: :value
#
# and access this configuration in your application as:
#
#     Application.get_env(:block, :key)
#
# You can also configure a 3rd-party app:
#
#     config :logger, level: :info
#

# It is also possible to import configuration files, relative to this
# directory. For example, you can emulate configuration per environment
# by uncommenting the line below and defining dev.exs, test.exs and such.
# Configuration from the imported file will override the ones defined
# here (which is why it is important to import them last).
#
import_config "#{config_env()}.exs"
