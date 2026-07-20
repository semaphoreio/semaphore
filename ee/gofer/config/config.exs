# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
import Mix.Config

config :grpc,
  start_server: true

config :gofer, ecto_repos: [Gofer.EctoRepo]

config :gofer, Gofer.EctoRepo,
  migration_timestamps: [type: :naive_datetime_usec],
  loggers: [
    # {Ecto.LogEntry, :log, [:debug]}
  ]

config :watchman,
  host: "localhost",
  port: 8125,
  prefix: "gofer.env-missing"

config :vmstats,
  sink: Gofer.VmstatsWatchmanSink,
  interval: 10_000

# Mappings to function definitions for functions available in when condition DSL
config :when, change_in: {Gofer.ChangeInResolver, :change_in, [1, 2]}

# Time to wait for plumber response
config :gofer, plumber_grpc_timeout: 6_000

# Time to wait betwween two plumber describe calls
config :gofer, pipeline_describe_pool_period: 5_000

# How long after pipeline is done should we try to auto-trigger targets (in seconds)
config :gofer, auto_trigger_deadline: 300

# Time to wait betwween two metric reports of engine process counts
config :gofer, engine_metrics_pool_period: 50_000

# How long target trigger can wait in queue before it is marked as failed (milliseconds)
config :gofer, target_trigger_ttl_ms: 40_000

# Maximum number of pending promotion requests per switch target (0 disables queue limit)
config :gofer, target_trigger_queue_limit: 50

# This configuration is loaded before any dependency and is restricted
# to this project. If another project depends on this project, this
# file won't be loaded nor affect the parent project. For this reason,
# if you want to provide default values for your application for
# 3rd-party users, it should be done in your "mix.exs" file.

# You can configure your application as:
#
#     config :gofer, key: :value
#
# and access this configuration in your application as:
#
#     Application.get_env(:gofer, :key)
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
import_config "#{Mix.env()}.exs"
