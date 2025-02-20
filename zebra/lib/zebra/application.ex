defmodule Zebra.Application do
  use Application

  require Logger

  @grpc_port 50_051

  alias Zebra.Workers

  def start(_type, _args) do
    {:ok, _} = Logger.add_backend(Sentry.LoggerBackend)
    provider = Application.fetch_env!(:zebra, :feature_provider)
    FeatureProvider.init(provider)

    #
    # Amqp is logging like a madman. To disable unnecessary logs,
    # we followed https://github.com/pma/amqp/issues/110#issuecomment-442761299.
    #
    :logger.add_primary_filter(
      :ignore_rabbitmq_progress_reports,
      {&:logger_filters.domain/2, {:stop, :equal, [:progress]}}
    )

    grpc_services =
      fake_services(Application.get_env(:zebra, :environment)) ++
        filter_enabled([
          {Zebra.Apis.PublicJobApi, enabled?("START_PUBLIC_JOB_API")},
          {Zebra.Apis.InternalJobApi, enabled?("START_INTERNAL_JOB_API")},
          {Zebra.Apis.InternalTaskApi, enabled?("START_INTERNAL_TASK_API")},
          {Zebra.Grpc.HealthCheck, enabled?("START_GRPC_HEALTH_CHECK")}
        ])

    grpc_enabled = Enum.count(grpc_services) > 0 && !IEx.started?()
    grpc_options = {grpc_services, @grpc_port}

    children =
      filter_enabled([
        {Zebra.LegacyRepo, true},
        {{GRPC.Server.Supervisor, grpc_options}, grpc_enabled},
        {provider, System.get_env("FEATURE_YAML_PATH") != nil},
        {Supervisor.child_spec({Cachex, :zebra_cache}, id: :zebra_cache), true},
        {Supervisor.child_spec({Cachex, :feature_provider_cache}, id: :feature_provider_cache),
         true}
      ])

    workers =
      Workers.active()
      |> Enum.map(fn w ->
        %{
          id: w,
          start: {w, :start_link, []}
        }
      end)

    children = children ++ workers

    Enum.each(children, fn c ->
      Logger.info("Starting: #{inspect(c)}")
    end)

    opts = [strategy: :one_for_one, name: Zebra.Supervisor, max_restarts: 1000]
    Supervisor.start_link(children, opts)
  end

  def enabled?(env_var) do
    System.get_env(env_var) == "true" && !IEx.started?()
  end

  def filter_enabled(list) do
    list
    |> Enum.filter(fn e -> elem(e, 1) end)
    |> Enum.map(fn e -> elem(e, 0) end)
  end

  def fake_services(:test),
    do: [
      Support.FakeServers.RBAC,
      Support.FakeServers.ProjecthubApi,
      Support.FakeServers.Loghub2Api,
      Support.FakeServers.OrganizationApi,
      Support.FakeServers.SecretsApi,
      Support.FakeServers.ArtifactApi,
      Support.FakeServers.CacheApi,
      Support.FakeServers.RepoProxyApi,
      Support.FakeServers.ChmuraApi,
      Support.FakeServers.SelfHosted,
      Support.FakeServers.RepositoryApi,
      Support.FakeServers.DeploymentTargetsApi
    ]

  def fake_services(_), do: []
end
