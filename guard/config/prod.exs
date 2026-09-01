import Config

config :guard, environment: :prod

config :oauth2, adapter: Tesla.Adapter.Hackney

config :tesla, adapter: Tesla.Adapter.Hackney

config :guard, :github_app_base_url, "https://github.com"
