import Config

config :logger, level: String.to_atom(System.get_env("LOG_LEVEL") || "info")

config :watchman,
  host: "0.0.0.0",
  port: 8125,
  prefix: "auth.#{System.get_env("METRICS_NAMESPACE") || "dev"}"

config :auth, force_ip_check: System.get_env("FORCE_IP_CHECK") == "true"

config :auth,
  trusted_proxies:
  System.get_env("LOAD_BALANCER_IP", "")
  |> String.split(",")
  |> Enum.map(fn s -> String.trim(s) end)
  |> Enum.filter(& &1)
  |> Enum.filter(& &1 != "")

config :auth, cookie_name: System.get_env("COOKIE_NAME")
config :auth, domain: System.get_env("BASE_DOMAIN")
config :auth, authentication_grpc_endpoint: System.fetch_env!("INTERNAL_API_URL_AUTHENTICATION")
config :auth, organization_grpc_endpoint: System.fetch_env!("INTERNAL_API_URL_ORGANIZATION")
config :auth, rbac_endpoint: System.fetch_env!("INTERNAL_API_URL_RBAC")
config :auth, feature_grpc_endpoint: System.fetch_env!("INTERNAL_API_URL_FEATURE")

config :sentry,
  dsn: System.get_env("SENTRY_DSN"),
  environment_name: config_env(),
  tags: %{
    application: "auth"
  },
  included_environments: [:prod]

on_prem? = if(System.get_env("ON_PREM") == "true", do: true, else: false)

config :auth, :on_prem?, on_prem?

feature_provider =
  System.get_env("FEATURE_YAML_PATH")
  |> case do
    nil -> {
      Auth.FeatureHubProvider,
      [
        cache: {FeatureProvider.CachexCache, name: :feature_provider_cache, ttl_ms: :timer.minutes(10)}
      ]
    }
    path -> {FeatureProvider.YamlProvider, [yaml_path: path, agent_name: :feature_provider_agent]}
  end

config :auth, :feature_provider, feature_provider
