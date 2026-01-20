defmodule Rbac.Application do
  @moduledoc false

  use Application

  require Logger

  @rbac_env Application.compile_env!(:rbac, :environment)

  def start(_type, _args) do
    Logger.info("Running application in #{@rbac_env} environment")

    children =
      [Rbac.Repo, Rbac.FrontRepo]
      |> add_grpc_service()
      |> add_workers()
      |> add_okta_services()
      |> add_task_supervisor()
      |> add_rabbit_workers()

    opts = [strategy: :one_for_one, name: Rbac.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp add_rabbit_workers(services) do
    if System.get_env("RABBIT_CONSUMER") == "true" do
      rabbit_workers() ++ services
    else
      services
    end
  end

  defp rabbit_workers do
    alias Rbac.Services

    [
      {Services.ProjectCreator, []},
      {Services.UserCreator, []},
      {Services.UserDeleted, []},
      {Services.UserUpdater, []},
      {Services.UserJoinedOrganization, []},
      {Services.UserLeftOrganization, []},
      {Services.ProjectDestroyer, []},
      {Services.OrganizationCreated, []},
      {Services.OrganizationDeleted, []}
    ]
  end

  defp add_task_supervisor(services) do
    task_supervisor = {Task.Supervisor, name: :rbac_task_supervisor, strategy: :one_for_one}
    [task_supervisor | services]
  end

  defp add_grpc_service(services) do
    grpc_supervisor =
      {GRPC.Server.Supervisor, servers: grpc_services(), port: 50_051, start_server: true}

    [grpc_supervisor | services]
  end

  defp add_okta_services(services), do: okta_services() ++ services

  defp okta_services do
    select_active([
      %{
        worker: {Plug.Cowboy, scheme: :http, plug: Rbac.Okta.Saml.Api, options: [port: 4001]},
        active: System.get_env("START_SAML_HTTP_API") == "true"
      },
      %{
        worker: {Plug.Cowboy, scheme: :http, plug: Rbac.Okta.Scim.Api, options: [port: 4002]},
        active: System.get_env("START_SCIM_HTTP_API") == "true"
      }
    ])
  end

  defp grpc_services do
    select_active([
      %{
        worker: Rbac.GrpcServers.HealthCheck,
        active: System.get_env("START_GRPC_HEALTH_CHECK") == "true"
      },
      %{
        worker: Rbac.GrpcServers.RbacServer,
        active: System.get_env("START_GRPC_RBAC_API") == "true"
      },
      %{
        worker: Rbac.GrpcServers.OktaServer,
        active: System.get_env("START_GRPC_OKTA_API") == "true"
      },
      %{
        worker: Rbac.GrpcServers.GroupsServer,
        active: System.get_env("START_GRPC_GROUPS_API") == "true"
      }
    ])
  end

  defp add_workers(services), do: services ++ workers()

  defp workers do
    select_active([
      %{
        worker: {Rbac.Refresh.Worker, []},
        active:
          System.get_env("START_RBAC_WORKERS") == "true" and
            System.get_env("IGNORE_REFRESH_REQUESTS") != "true"
      },
      %{
        worker: {Rbac.Workers.RefreshAllPermissions, []},
        active: System.get_env("START_RBAC_WORKERS") == "true"
      },
      %{
        worker: {Rbac.Workers.RefreshProjectAccess, []},
        active: System.get_env("START_RBAC_WORKERS") == "true"
      },
      %{
        worker: {Rbac.Workers.GroupManagement, []},
        active: System.get_env("START_RBAC_WORKERS") == "true"
      },
      %{
        worker: {Rbac.Workers.MonitorNewAuditLogs, []},
        active: System.get_env("START_RBAC_WORKERS") == "true"
      },
      %{
        worker: {Rbac.Okta.Scim.Provisioner, []},
        active: System.get_env("START_RBAC_WORKERS") == "true"
      }
    ])
  end

  defp select_active(workers) do
    workers
    |> Enum.filter(fn %{worker: _w, active: active} -> active end)
    |> Enum.map(fn %{worker: worker, active: _a} -> worker end)
  end
end
