import Config

# Ppl configuration

config :ppl,
  ecto_repos: [Ppl.EctoRepo]

config :ppl, Ppl.EctoRepo,
  adapter: Ecto.Adapters.Postgres,
  database: System.get_env("POSTGRES_DB_NAME"),
  username: System.get_env("POSTGRES_DB_USER"),
  password: System.get_env("POSTGRES_DB_PASSWORD"),
  hostname: System.get_env("POSTGRES_DB_HOST"),
  pool_size: String.to_integer(System.get_env("POSTGRES_DB_POOL_SIZE") || "1"),
  ssl: System.get_env("POSTGRES_DB_SSL") == "true" || false,
  parameters: [application_name: "plumber-ppl"],
  loggers: [
    {Ecto.LogEntry, :log, [:debug]}
  ]

config :watchman,
  host: "localhost",
  port: 8125,
  prefix: "ppl.env-missing"

config :grpc,
  start_server: true,
  http2_client_adapter: GRPC.Adapter.Gun

config :vmstats,
  sink: Ppl.VmstatsWatchmanSink,
  interval: 10_000

# Mappings to function definitions for functions available in when condition DSL
config :when, change_in: {Block.ChangeInResolver, :change_in, [1, 2]}

# Number of log lines per second
config :logger, :console, max_buffer: 100

# Time to wait for gofer response
config :gofer_client, gofer_grpc_timeout: 4_567

# Time in hours before delete requests are processed
config :ppl, deletion_offset_h: 24

# Retention policy event consumer
config :ppl, Ppl.Retention.PolicyConsumer,
  exchange: System.get_env("USAGE_POLICY_EXCHANGE"),
  routing_key: System.get_env("USAGE_POLICY_ROUTING_KEY")

# Retention policy grace period in days before data is deleted (min: 7, default: 15)
config :ppl, Ppl.Retention.PolicyApplier,
  grace_period_days: String.to_integer(System.get_env("RETENTION_GRACE_PERIOD_DAYS") || "15")

# How many times should wormhole retry to publish pipeline events to RabbitMQ
config :ppl, publish_retry_count: 3
# Timeout for publishing pipeline events to RabbitMQ
config :ppl, publish_timeout: 500

# Time to wait before pipeline status is reexamined in seconds
config :ppl, general_looper_cooling_time_sec: 1
# Specific cooling time values for each looper, uncomment to override general one
config :ppl, ppl_initializing_ct: 0
config :ppl, ppl_pending_ct: 0
# config :ppl, ppl_queuing_ct: 1
# config :ppl, ppl_running_ct: 1
# config :ppl, ppl_stopping_ct: 1
config :ppl, ppl_blk_initializing_ct: 0
config :ppl, ppl_blk_waiting_ct: 0
# config :ppl, ppl_blk_running_ct: 1
# config :ppl, ppl_blk_stopping_ct: 1
config :ppl, ppl_sub_init_created_ct: 0
config :ppl, ppl_sub_init_regular_init_ct: 0
# config :ppl, ppl_after_task_waiting_ct: 0
# config :ppl, ppl_after_task_pending_ct: 0
# config :ppl, ppl_after_task_running_ct: 0
# config :ppl, tl_tracking_ct: 1
# config :ppl, dr_pending_ct: 1
# config :ppl, dr_deleting_ct: 1
# config :ppl, dr_queue_deleting_ct: 1

# Time period looper will sleep between scheduling in miliseconds
config :ppl, general_sleeping_period_ms: 1000
# Specific Time period values for each looper, uncomment to override general one
# config :ppl, ppl_initializing_sp: 1000
# config :ppl, ppl_pending_sp: 1000
# config :ppl, ppl_queuing_sp: 1000
# config :ppl, ppl_running_sp: 1000
# config :ppl, ppl_stopping_sp: 1000
# config :ppl, ppl_blk_waiting_sp: 1000
# config :ppl, ppl_blk_running_sp: 1000
# config :ppl, ppl_blk_stopping_sp: 1000
# config :ppl, ppl_sub_init_created_sp: 1000
# config :ppl, ppl_sub_init_regular_init_sp: 1000
# config :ppl, ppl_after_task_waiting_sp: 1000
# config :ppl, ppl_after_task_pending_sp: 1000
# config :ppl, ppl_after_task_running_sp: 1000
# config :ppl, tl_tracking_sp: 1000
config :ppl, dr_pending_sp: 30_000
config :ppl, dr_deleting_sp: 30_000
config :ppl, dr_queue_deleting_sp: 30_000

# Sleep period for StateWatch loopers
config :ppl, state_watch_sleep_period_ms: 30_000
# Sleep period for StateResidency loopers
config :ppl, state_residency_sleep_period_ms: 20_000

# Interval between two Beholder execution
config :ppl, beholder_sleep_period_sec: 3
# Interval after which stuck ppl is moved out of scheduling state
config :ppl, beholder_threshold_sec: 20
# Stuck pipeline can be recovered at most n times
config :ppl, beholder_threshold_count: 5

# Interval between two Ppl Block Beholder execution
config :ppl, beholder_ppl_blk_sleep_period_sec: 3
# Interval after which stuck ppl block is moved out of scheduling state
config :ppl, beholder_ppl_blk_threshold_sec: 20
# Stuck pipeline block can be recovered at most n times
config :ppl, beholder_ppl_blk_threshold_count: 5

# Interval between two ppl_sub_init Beholder executions
config :ppl, beholder_sub_init_sleep_period_sec: 3
# Interval after which stuck ppl_sub_init is moved out of scheduling state
config :ppl, beholder_sub_init_threshold_sec: 20
# Stuck ppl_sub_inits can be recovered at most n times
config :ppl, beholder_sub_init_threshold_count: 5

# Interval between two time_limits Beholder executions
config :ppl, beholder_time_limits_sleep_period_sec: 3
# Interval after which stuck time_limit is moved out of scheduling state
config :ppl, beholder_time_limits_threshold_sec: 20
# Stuck time_limit can be recovered at most n times
config :ppl, beholder_time_limits_threshold_count: 5

# Interval between two delete_request Beholder executions
config :ppl, beholder_dr_sleep_period_sec: 60
# Interval after which stuck delete_request is moved out of scheduling state
config :ppl, beholder_dr_threshold_sec: 20
# Stuck delete_request can be recovered at most n times
config :ppl, beholder_dr_threshold_count: 5

# Encryption module config
config :cloak, Cloak.AES.GCM,
  default: true,
  tag: "GCM",
  keys: [
    %{tag: <<1>>, key: {:system, "USER_CREDS_ENC_KEY_1"}, default: true}
  ]

# Block configuration

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
  parameters: [application_name: "plumber-ppl"],
  loggers: [
    {Ecto.LogEntry, :log, [:debug]}
  ]

# Time to wait before block status is reexamined
config :block, general_looper_cooling_time_sec: 1
# Specific cooling time values for each looper, uncomment to override general one
config :block, blk_initializing_ct: 0
# config :block, blk_running_ct: 1
# config :block, blk_stopping_ct: 1
config :block, task_pending_ct: 0
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

# Interval between two Blok Beholder executions
config :block, beholder_blk_sleep_period_sec: 3
# Interval after which stuck block is moved out of scheduling state
config :block, beholder_blk_threshold_sec: 10
# Stuck block build can be recovered at most n times
config :block, beholder_blk_threshold_count: 5

# Interval between two Task Beholder executions
config :block, beholder_task_sleep_period_sec: 3
# Interval after which stuck task is moved out of scheduling state
config :block, beholder_task_threshold_sec: 10
# Stuck task can be recovered at most n times
config :block, beholder_task_threshold_count: 300

config :block,
  block_done_notification_callback:
    {Ppl.PplBlocks.STMHandler.Common, :block_done_notification_callback}

config :block,
  compile_task_done_notification_callback:
    {Ppl.PplSubInits.STMHandler.Common, :compile_task_done_notification_callback}

config :block,
  after_ppl_task_done_notification_callback:
    {Ppl.AfterPplTasks.STMHandler.Common, :after_ppl_task_done_notification_callback}

# disable logging of ecto queries
config :logger, level: :info
# for debugging queries
# config :logger, level: :debug

import_config "#{config_env()}.exs"
