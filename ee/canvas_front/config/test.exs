import Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :canvas_front, CanvasFrontWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "triY5VBYfAPdZYcBeKF0bS1JIM9Umk5oP6Xvawsma64Tt9FS5M3IlkfSLgx3FybD",
  server: false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

config :canvas_front, :domain, "localhost:4000"
config :canvas_front, :assets_path, "https://semaphore.semaphoreci.com/projects/assets"

config :canvas_front, delivery_grpc_endpoint: "127.0.0.1:50052"

config :canvas_front, dev_routes: true
