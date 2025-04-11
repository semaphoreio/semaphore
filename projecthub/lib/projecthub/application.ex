defmodule Projecthub.Application do
  @moduledoc false

  require Logger
  use Application

  def start(_type, _args) do
    env = Application.fetch_env!(:projecthub, :environment)
    port = Application.fetch_env!(:projecthub, :grpc_port)
    provider = Application.fetch_env!(:projecthub, :feature_provider)
    FeatureProvider.init(provider)

    Logger.info("Running application in #{env} environment")

    # Disables too verbose logging from amqp supervisors
    :logger.add_primary_filter(
      :ignore_rabbitmq_progress_reports,
      {&:logger_filters.domain/2, {:stop, :equal, [:progress]}}
    )

    start_server? = enabled?(:start_internal_api?)
    start_worker? = enabled?(:start_project_init_worker?)
    start_cleaner = enabled?(:start_project_cleaner?)

    children =
      [
        {Projecthub.Repo, []},
        {Projecthub.Workers.AgentStore, [name: :feature_store]},
        {Task.Supervisor, [name: Projecthub.TaskSupervisor]},
        {Projecthub.FeatureProviderInvalidatorWorker, []},
        %{
          id: FeatureProvider.Cachex,
          start: {Cachex, :start_link, [:feature_provider_cache, []]}
        }
      ] ++
        filter_enabled([
          {provider, System.get_env("FEATURE_YAML_PATH") != nil},
          {{Support.MemoryDb, []}, env != :prod},
          {{Projecthub.Workers.ProjectInit, []}, start_worker?},
          {{GRPC.Server.Supervisor, {Projecthub.Api.Endpoint, port}}, start_server?},
          {{Projecthub.Workers.ProjectCleaner, []}, start_cleaner}
        ])

    Enum.each(children, fn c ->
      Logger.info("Starting: #{inspect(c)}")
    end)

    opts = [strategy: :one_for_one, name: Projecthub.Supervisor]

    if env == :prod do
      {:ok, _} = Logger.add_backend(Sentry.LoggerBackend)
    end

    Supervisor.start_link(children, opts)
  end

  defp filter_enabled(list) do
    list
    |> Enum.filter(fn e -> elem(e, 1) end)
    |> Enum.map(fn e -> elem(e, 0) end)
  end

  defp enabled?(env_var) do
    # System.get_env(env_var) == "true" && !IEx.started?()
    Application.get_env(:projecthub, env_var) == "true" && !IEx.started?()
  end
end
