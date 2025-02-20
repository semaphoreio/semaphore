import Config

config :watchman,
  host: "localhost",
  port: 8125,
  prefix: "pre_flight_checks"

config :vmstats,
  sink: VMStats.WatchmanSink,
  interval: 10_000

# Number of log lines per second
config :logger, :console, max_buffer: 100

# Do not log debug info
config :logger, level: :info
