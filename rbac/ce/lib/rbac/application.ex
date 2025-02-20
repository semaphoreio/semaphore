defmodule Rbac.Application do
  @moduledoc false

  use Application

  require Logger

  @rbac_env Application.compile_env!(:rbac, :environment)

  def start(_type, _args) do
    Logger.info("Running application in #{@rbac_env} environment")

    children =
      [Rbac.Repo]
      |> add_grpc_service()
      |> add_rabbit_consumers()

    opts = [strategy: :one_for_one, name: Rbac.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp add_grpc_service(services) do
    grpc_supervisor =
      {GRPC.Server.Supervisor, servers: grpc_services(), port: 50_051, start_server: true}

    [grpc_supervisor | services]
  end

  defp grpc_services do
    [
      Rbac.GrpcServers.HealthCheck,
      Rbac.GrpcServers.RbacServer
    ]
  end

  defp add_rabbit_consumers(services), do: rabbit_consumers() ++ services

  defp rabbit_consumers do
    alias Rbac.Services

    [
      {Services.UserDeleted, []},
      {Services.ProjectDeleted, []},
      {Services.OrganizationCreated, []},
      {Services.OrganizationDeleted, []}
    ]
  end
end
