import Config

config :auth, http_port: 4000

import_config "#{config_env()}.exs"
