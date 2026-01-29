defmodule Guard.Application do
  @moduledoc false

  use Application
  alias Guard.Services

  require Logger

  @guard_env Application.compile_env!(:guard, :environment)

  def start(_type, _args) do
    Logger.info("Running application in #{@guard_env} environment")

    if start_fun_registry?(@guard_env) do
      {:ok, _} = FunRegistry.start()
    end

    # Disables too verbose logging from amqp supervisors
    :logger.add_primary_filter(
      :ignore_rabbitmq_progress_reports,
      {&:logger_filters.domain/2, {:stop, :equal, [:progress]}}
    )

    services = [Guard.Repo, Guard.FrontRepo] ++ start_instance_config()

    children = add_api_servers(services)
    children = children ++ init_feature_provider()

    children = children ++ caches()

    if @guard_env == :prod do
      {:ok, _} = Logger.add_backend(Sentry.LoggerBackend)
    end

    opts = [strategy: :one_for_one, name: Guard.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp start_fun_registry?(env) when env in [:test, :dev], do: true
  defp start_fun_registry?(_env), do: false

  defp start_instance_config do
    if System.get_env("START_INSTANCE_CONFIG") == "true" do
      [Guard.InstanceConfigRepo]
    else
      []
    end
  end

  defp init_feature_provider do
    with {:start, "true"} <- {:start, System.get_env("START_FEATURE_PROVIDER")},
         feature_provider <- Application.fetch_env!(:guard, :feature_provider),
         :ok <- FeatureProvider.init(feature_provider),
         {:yaml_provider, true} <- {:yaml_provider, !is_nil(System.get_env("FEATURE_YAML_PATH"))} do
      [feature_provider]
    else
      {:start, _} ->
        []

      {:yaml_provider, false} ->
        [{Guard.Services.FeatureProviderInvalidatorWorker, []}]

      _ ->
        []
    end
  end

  defp add_api_servers(services) do
    grpc = System.get_env("GRPC_API") || "true"
    rabbit = System.get_env("RABBIT_CONSUMER") || "true"
    id = System.get_env("ID_API") || "false"
    instance_config_api = System.get_env("INSTANCE_CONFIG_API") || "false"
    organization_cleaner = System.get_env("START_ORGANIZATION_CLEANER") || "false"

    services
    |> add_grpc_service(grpc)
    |> add_test_grpc_service(grpc, @guard_env)
    |> add_id_service(id)
    |> add_instance_config_api(instance_config_api)
    |> add_rabbit_workers(rabbit)
    |> add_organization_cleaner(organization_cleaner)
  end

  defp add_grpc_service(services, "true") do
    services ++
      [
        Supervisor.child_spec({GRPC.Server.Supervisor, {grpc_services(), 50_051}},
          id: :grpc_supervisor
        )
      ]
  end

  defp add_grpc_service(services, _), do: services

  defp add_test_grpc_service(services, "true", :test) do
    services ++
      [
        Supervisor.child_spec({GRPC.Server.Supervisor, {fake_grpc_services(), 50_052}},
          id: :fake_grpc_supervisor
        )
      ]
  end

  defp add_test_grpc_service(services, _, _), do: services

  defp add_id_service(services, "true") do
    services ++
      [
        {Plug.Cowboy, scheme: :http, plug: Guard.Id.Api, options: [port: 4003]},
        {Services.InstanceConfigInvalidatorWorker, []}
      ]
  end

  defp add_id_service(services, _), do: services

  defp add_instance_config_api(services, "true") do
    services ++
      [{Plug.Cowboy, scheme: :http, plug: Guard.InstanceConfig.Api, options: [port: 4004]}]
  end

  defp add_instance_config_api(services, _), do: services

  defp add_rabbit_workers(services, "true") do
    services ++ rabbit_workers()
  end

  defp add_rabbit_workers(services, _), do: services

  defp add_organization_cleaner(services, "true") do
    services ++ organization_cleaner()
  end

  defp add_organization_cleaner(services, _), do: services

  defp select_active(workers) do
    workers
    |> Enum.filter(fn %{worker: _w, active: active} -> active end)
    |> Enum.map(fn %{worker: worker, active: _a} -> worker end)
  end

  defp rabbit_workers do
    [
      {Services.OrganizationSuspended, []},
      {Services.OrganizationUnsuspended, []},
      {Services.OrganizationMachinesChanged, []}
    ]
  end

  defp organization_cleaner, do: [{Guard.OrganizationCleaner, []}]

  defp caches do
    select_active([
      %{
        worker: Supervisor.child_spec({Cachex, :ppl_cache}, id: :ppl_cache),
        active: true
      },
      %{
        worker:
          Supervisor.child_spec({Cachex, :feature_provider_cache}, id: :feature_provider_cache),
        active: true
      },
      %{
        worker: Supervisor.child_spec({Cachex, :config_cache}, id: :config_cache),
        active: true
      }
    ])
  end

  defp grpc_services do
    select_active([
      %{
        worker: GrpcHealthCheck.Server,
        active: System.get_env("START_GPRC_HEALTH_CHECK") == "true"
      },
      %{
        worker: Guard.GrpcServers.Server,
        active: System.get_env("START_GPRC_GUARD_API") == "true"
      },
      %{
        worker: Guard.GrpcServers.AuthServer,
        active: System.get_env("START_GRPC_AUTH_API") == "true"
      },
      %{
        worker: Guard.GrpcServers.UserServer,
        active: System.get_env("START_GRPC_USER_API") == "true"
      },
      %{
        worker: Guard.GrpcServers.ServiceAccountServer,
        active: System.get_env("START_GRPC_SERVICE_ACCOUNT_API") == "true"
      },
      %{
        worker: Guard.GrpcServers.InstanceConfigServer,
        active: System.get_env("START_GRPC_INSTANCE_CONFIG_API") == "true"
      },
      %{
        worker: Guard.GrpcServers.OrganizationServer,
        active: System.get_env("START_GRPC_ORGANIZATION_API") == "true"
      },
    ])
  end

  defp fake_grpc_services do
    select_active([
      %{
        worker: Support.Fake.OrganizationService,
        active: @guard_env == :test
      },
      %{
        worker: Support.Fake.SecretService,
        active: @guard_env == :test
      },
      %{
        worker: Support.Fake.RepositoryService,
        active: @guard_env == :test
      },
      %{
        worker: Support.Fake.RbacService,
        active: @guard_env == :test
      },
      %{
        worker: Support.Fake.OktaService,
        active: @guard_env == :test
      }
    ])
  end
end
