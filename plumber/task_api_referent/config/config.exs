import Config

config(:sys2app,
  :callback, {TaskApiReferent.Sys2app, :callback, []})

config :watchman,
    host: "localhost",
    port: 8125,
    prefix: "task-referent.env-missing"

config :grpc,
  start_server: true

import_config "#{config_env()}.exs"
