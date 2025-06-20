import Config

if System.get_env("TZDATA_DATA_DIRECTORY") != nil do
    config :tzdata, :data_dir, System.get_env("TZDATA_DATA_DIRECTORY")
  else
    config :tzdata, :autoupdate, :disabled
  end

config :sentry,
    dsn: System.get_env("SENTRY_DSN"),
    enable_source_code_context: true,
    root_source_code_path: File.cwd!(),
    included_environments: ~w(prod pre-prod),
    environment_name: System.get_env("SENTRY_ENV") || "development"

if config_env() == :prod do
  config :projecthub,
    projecthub_grpc_endpoint: System.fetch_env!("INTERNAL_API_URL_PROJECT"),
    organization_grpc_endpoint: System.fetch_env!("INTERNAL_API_URL_ORGANIZATION"),
    rbac_grpc_endpoint: System.fetch_env!("INTERNAL_API_URL_RBAC"),
    projects_page_size: System.get_env("PROJECTS_PAGE_SIZE", "500") |> String.to_integer()
end
