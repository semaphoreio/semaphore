import Config

config :block, environment: :test

config :block, Block.EctoRepo,
  ownership_timeout: 600000,
  timeout: 60_000

# Time to wait before block status is reexamined
# -2 means 'do not wait' or take all
config :block, general_looper_cooling_time_sec: -2

# Interval between two Blocks Beholder executiond
config :block, beholder_blk_sleep_period_sec: 1
# Interval after which stuck block build is moved out of scheduling state
config :block, beholder_blk_threshold_sec: -2

# Interval between two Block Build Beholder execution
config :block, beholder_task_sleep_period_sec: 1
# Interval after which stuck block is moved out of scheduling state
config :block, beholder_task_threshold_sec: -2

config :watchman,
    host: "localhost",
    port: 8125,
    prefix: "block.test"

config :junit_formatter,
  report_dir: "./out",
  report_file: "results.xml",
  print_report_file: true,
  include_filename?: true,
  include_file_line?: true
