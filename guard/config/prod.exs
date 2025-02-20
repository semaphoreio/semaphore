import Config

config :guard, environment: :prod

config :oauth2, adapter: Tesla.Adapter.Hackney

config :tesla, adapter: Tesla.Adapter.Hackney

config :guard, :github_app_install_url, "https://github.com/settings/apps/new"
