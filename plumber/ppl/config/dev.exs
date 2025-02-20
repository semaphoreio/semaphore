import Config

config :ppl, environment: :dev

config :watchman,
  host: "localhost",
  port: 8125,
  prefix: "ppl.dev"

config :ppl, Ppl.Cache.OrganizationSettings,
  cache_name: :organization_settings,
  enabled?: true,
  expiration_ttl: 120,
  expiration_interval: 60,
  size_limit: 1_000,
  reclaim_coef: 0.5
