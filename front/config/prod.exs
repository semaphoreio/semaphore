import Config

config :front, :environment, :prod

config :front, FrontWeb.Endpoint,
  load_from_system_env: true,
  url: [host: System.get_env("BASE_DOMAIN"), port: 80],
  cache_static_manifest: "priv/static/cache_manifest.json"

config :front, :superjerry_client, {Front.Clients.Superjerry, []}
config :front, :service_account_client, {Front.Clients.ServiceAccount, []}
config :front, guard_grpc_timeout: 15_000
config :front, permission_patrol_timeout: 15_000
config :front, me_host: "me.", me_path: "/"
