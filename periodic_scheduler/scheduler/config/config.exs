# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
import Mix.Config

config :watchman,
  host: "localhost",
  port: 8125,
  prefix: "periodic-sch.env-missing"

config :vmstats,
  sink: Scheduler.VmstatsWatchmanSink,
  interval: 10_000

config :scheduler,
  ecto_repos: [Scheduler.PeriodicsRepo, Scheduler.FrontRepo]

config :scheduler, Scheduler.PeriodicsRepo,
  migration_timestamps: [type: :naive_datetime_usec],
  pool_size: 2

config :scheduler, Scheduler.FrontRepo, pool_size: 2

config :grpc, start_server: true

config :scheduler, Scheduler.Workers.QuantumScheduler, timeout: 16_000

# disable logging of ecto queries
config :logger, level: :info
# for debugging queries
# config :logger, level: :debug

import_config "#{Mix.env()}.exs"
