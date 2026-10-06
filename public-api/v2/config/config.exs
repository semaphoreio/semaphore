# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
import Config

config :public_api, :environment, config_env()

config :public_api, grpc_timeout: 30_000

config :watchman,
  host: "localhost",
  port: 8125,
  prefix: "ppl-api.env-missing"

import_config "#{config_env()}.exs"
