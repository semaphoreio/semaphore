defmodule Front.Application do
  @moduledoc false

  require Logger
  use Application

  def start(_type, _args) do
    Logger.info("Running application in #{Application.get_env(:front, :environment)} environment")

    provider = Application.fetch_env!(:front, :feature_provider)
    FeatureProvider.init(provider)

    # Disables too verbose logging from amqp supervisors
    :logger.add_primary_filter(
      :ignore_rabbitmq_progress_reports,
      {&:logger_filters.domain/2, {:stop, :equal, [:progress]}}
    )

    base_children = [
      {Phoenix.PubSub, [name: Front.PubSub, adapter: Phoenix.PubSub.PG2]},
      FrontWeb.Endpoint,
      {Task.Supervisor, [name: Front.TaskSupervisor]},
      Front.Tracing.Store,
      Front.FeatureProviderInvalidatorWorker
    ]

    children =
      base_children ++
        reactor() ++
        cache() ++
        telemetry() ++
        feature_provider(provider) ++
        clients()

    opts = [strategy: :one_for_one, name: Front.Supervisor]

    unless Application.get_env(:front, :environment) in [:dev, :test] do
      {:ok, _} = Logger.add_backend(Sentry.LoggerBackend)
    end

    Enum.each(children, fn c ->
      Logger.info("Starting: #{inspect(c)}")
    end)

    Supervisor.start_link(children, opts)
  end

  def cache do
    import Cachex.Spec

    front_opts = %{
      prefix: Application.get_env(:front, :cache_prefix),
      backend: %{
        type: :redis,
        host: Application.get_env(:front, :cache_host),
        port: Application.get_env(:front, :cache_port),
        pool_size: Application.get_env(:front, :cache_pool_size)
      }
    }

    [
      {Cacheman, [:front, front_opts]},
      Supervisor.child_spec({Cachex, :feature_provider_cache}, id: :feature_provider_cache),

      # old, deprecated caches. Do not use.
      Supervisor.child_spec({Cachex, :front_cache}, id: :front_cache),
      Supervisor.child_spec(
        {Cachex, name: :auth_cache, expiration: expiration(default: :timer.minutes(5))},
        id: :auth_cache
      )
    ]
  end

  def telemetry do
    if Application.get_env(:front, :start_telemetry) == "true" do
      [Front.Telemetry.Scheduler]
    else
      []
    end
  end

  def reactor do
    if Application.get_env(:front, :start_reactor) == "true" do
      [
        Front.BranchPage.CacheInvalidator,
        Front.ProjectPage.CacheInvalidator,
        Front.Layout.CacheInvalidator,
        Front.WorkflowPage.PipelineStatus.CacheInvalidator
      ]
    else
      []
    end
  end

  def feature_provider(provider) do
    if System.get_env("FEATURE_YAML_PATH") != nil do
      [provider]
    else
      []
    end
  end

  def clients do
    Application.get_env(:front, :service_account_client)
    |> case do
      {client_mod, _} = client when client_mod in [Support.FakeClients.ServiceAccount] ->
        [client]

      _ ->
        []
    end
  end

  def config_change(changed, _new, removed) do
    FrontWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
