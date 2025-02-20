import Config

config :block, environment: :dev

config :watchman,
    host: "localhost",
    port: 8125,
    prefix: "block.dev"
