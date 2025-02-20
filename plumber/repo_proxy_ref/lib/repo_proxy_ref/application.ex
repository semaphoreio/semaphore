defmodule RepoProxyRef.Application do
  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, args) do
    import Supervisor.Spec, warn: false

    services = [
      RepoProxyRef.Grpc.Server,
      RepoProxyRef.Grpc.HealthCheck
    ]

    port = System.get_env("GRPC_PORT") |> String.to_integer()

    children = [
      supervisor(GRPC.Server.Supervisor, [{services, port}]),
    ]

    # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: RepoProxyRef.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
