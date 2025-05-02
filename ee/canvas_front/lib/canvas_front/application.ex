defmodule CanvasFront.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children =
      [
        CanvasFrontWeb.Telemetry,
        {DNSCluster, query: Application.get_env(:canvas_front, :dns_cluster_query) || :ignore},
        {Phoenix.PubSub, name: CanvasFront.PubSub},
        # Start the Finch HTTP client for sending emails
        {Finch, name: CanvasFront.Finch},
        # Start a worker by calling: CanvasFront.Worker.start_link(arg)
        # {CanvasFront.Worker, arg},
        # Start to serve requests, typically the last entry
        CanvasFrontWeb.Endpoint
      ] ++ cache()

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: CanvasFront.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp cache do
    [
      {Cachex, [:canvas_front_cache]},
      %{
        id: FeatureProvider.Cachex,
        start: {Cachex, :start_link, [:feature_provider_cache, []]}
      }
    ]
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    CanvasFrontWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
