defmodule GithubNotifier.Application do
  require Logger
  use Application

  alias GithubNotifier.Services

  def start(_type, _args) do
    env = Application.get_env(:github_notifier, :environment)

    Logger.info("Running application in #{env} environment")

    # Disables too verbose logging from amqp supervisors
    :logger.add_primary_filter(
      :ignore_rabbitmq_progress_reports,
      {&:logger_filters.domain/2, {:stop, :equal, [:progress]}}
    )

    children = child_specs(enabled?("START_API"), enabled?("START_CONSUMERS"), feature_provider())

    Enum.each(children, fn c ->
      Logger.info("Starting: #{inspect(c)}")
    end)

    {:ok, _} = Logger.add_backend(Sentry.LoggerBackend)
    Logger.configure_backend(Sentry.LoggerBackend, include_logger_metadata: true)

    opts = [strategy: :rest_for_one, name: GithubNotifier.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @doc false
  def child_specs(api?, consumers?, feature_provider_entry) do
    [
      {Task.Supervisor, name: GithubNotifier.TaskSupervisor},
      %{id: Cachex, start: {Cachex, :start_link, [:store, []]}},
      %{
        id: FeatureProvider.Cachex,
        start: {Cachex, :start_link, [:feature_provider_cache, []]}
      },
      GithubNotifier.StatusSender
    ] ++
      filter_enabled([
        feature_provider_entry,
        {{GRPC.Server.Supervisor, {grpc_services(), 50_051}}, api?},
        {{Services.BlockFinishedNotifier, []}, consumers?},
        {{Services.PipelineStartedNotifier, []}, consumers?},
        {{Services.PipelineFinishedNotifier, []}, consumers?},
        {{Services.PipelineSummaryAvailableNotifier, []}, consumers?},
        {{GithubNotifier.FeatureProviderInvalidatorWorker, []}, true}
      ])
  end

  defp enabled?(env_var) do
    System.get_env(env_var) == "true" && !IEx.started?()
  end

  defp filter_enabled(list) do
    list
    |> Enum.filter(fn e -> elem(e, 1) end)
    |> Enum.map(fn e -> elem(e, 0) end)
  end

  defp grpc_services, do: [GithubNotifier.Services.Api]

  defp feature_provider do
    provider = Application.get_env(FeatureProvider, :provider)

    {provider, System.get_env("FEATURE_YAML_PATH") != nil}
  end
end
