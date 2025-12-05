import Config

config :ppl, environment: :test

# Ppl configuration

config :ppl,
  ecto_repos: [Ppl.EctoRepo, Block.EctoRepo]

config :ppl, Ppl.EctoRepo,
  ownership_timeout: 600_000,
  timeout: 60_000

config :ppl, Ppl.Cache.OrganizationSettings,
  cache_name: :organization_settings,
  enabled?: true,
  expiration_ttl: 120,
  expiration_interval: 60,
  size_limit: 1_000,
  reclaim_coef: 0.5

# Time to wait before pipeline status is reexamined
# -2 means 'do not wait' or take all
config :ppl, general_looper_cooling_time_sec: -2
# Time period looper will sleep between scheduling in miliseconds
config :ppl, general_sleeping_period_ms: 100
config :ppl, ppl_pending_sp: 100

# Interval between two Beholder execution
config :ppl, beholder_sleep_period_sec: 1
# Interval after which stuck ppl is moved uout of scheduling state
config :ppl, beholder_threshold_sec: -2

# Interval between two Ppl Block Beholder execution
config :ppl, beholder_ppl_blk_sleep_period_sec: 1
# Interval after which stuck ppl block is moved out of scheduling state
config :ppl, beholder_ppl_blk_threshold_sec: -2
# Stuck pipeline block can be recovered at most n times
config :ppl, beholder_ppl_blk_threshold_count: 2

# How many times should wormhole retry to publish pipeline events to RabbitMQ
config :ppl, publish_retry_count: 1

# DeleteRequest loopers configs
config :ppl, deletion_offset_h: -1
config :ppl, dr_pending_sp: 100
config :ppl, dr_deleting_sp: 100
config :ppl, dr_queue_deleting_sp: 100

config :ppl, Ppl.Retention.PolicyConsumer,
  exchange: "usage_internal_api_test",
  routing_key: "usage.apply_organization_policy.test"

config :watchman,
  host: "localhost",
  port: 8125,
  prefix: "ppl.test"

# Block configuration

config :block, Block.EctoRepo,
  ownership_timeout: 600_000,
  timeout: 60_000

# Time to wait before block status is reexamined
# -2 means 'do not wait' or take all
config :block, general_looper_cooling_time_sec: -2
# Time period looper will sleep between scheduling in miliseconds
config :block, general_sleeping_period_ms: 100

# Interval between two Block Beholder executions
config :block, beholder_blk_sleep_period_sec: 1
# Interval after which stuck block is moved uout of scheduling state
config :block, beholder_blk_threshold_sec: -2

# Interval between two Task Beholder executions
config :block, beholder_task_sleep_period_sec: 1
# Interval after which stuck task is moved uout of scheduling state
config :block, beholder_task_threshold_sec: -2

config :junit_formatter,
  automatic_create_dir?: true,
  report_dir: "./out",
  report_file: "test-reports.xml",
  print_report_file: true,
  include_filename?: true,
  include_file_line?: true
