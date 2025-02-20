import Config

config :ppl, environment: :prod

config :logger, level: :info
# config :logger, level: :debug

config :ppl, Ppl.Cache.OrganizationSettings,
  cache_name: :organization_settings,
  enabled?: true,
  expiration_ttl: 900,
  expiration_interval: 300,
  size_limit: 1_000,
  reclaim_coef: 0.25

config :logger, :console, format: "$time $metadata[$level] $message\n"
