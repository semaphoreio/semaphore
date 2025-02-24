defmodule Auth.Application do
  @moduledoc false

  require Logger

  use Application

  def start(_type, _args) do
    port = Application.fetch_env!(:auth, :http_port)
    provider = Application.fetch_env!(:auth, :feature_provider)
    FeatureProvider.init(provider)

    Logger.info("Starting applicaiton server on localhost:#{port}")

    children = [
      Plug.Cowboy.child_spec(scheme: :http, plug: Auth, options: [port: port]),
      %{id: Cachex, start: {Cachex, :start_link, [:grpc_api_cache, []]}}
    ]

    {:ok, _} = Logger.add_backend(Sentry.LoggerBackend)

    opts = [strategy: :one_for_one, name: Auth.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
