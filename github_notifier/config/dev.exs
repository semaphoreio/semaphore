import Config

config :github_notifier, environment: :dev

config :logger, level: :debug
config :logger, :console,
  format: "$level$levelpad[$metadata] $message\n",
  metadata: [:request_id]

config :github_notifier, host: "boxbox.local:3000"
config :github_notifier, amqp_url: "amqp://localhost:5672"
