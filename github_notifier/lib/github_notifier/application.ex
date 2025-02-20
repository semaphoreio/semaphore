defmodule GithubNotifier.Application do
  require Logger
  use Application

  def start(_type, _args) do
    alias GithubNotifier.Services

    env = Application.get_env(:github_notifier, :environment)

    Logger.info("Running application in #{env} environment")

    # Disables too verbose logging from amqp supervisors
    :logger.add_primary_filter(
      :ignore_rabbitmq_progress_reports,
      {&:logger_filters.domain/2, {:stop, :equal, [:progress]}}
    )

    children =
      filter_enabled([
        {{GRPC.Server.Supervisor, {grpc_services(), 50_051}}, enabled?("START_API")},
        {{Services.BlockFinishedNotifier, []}, enabled?("START_CONSUMERS")},
        {{Services.PipelineStartedNotifier, []}, enabled?("START_CONSUMERS")},
        {{Services.PipelineFinishedNotifier, []}, enabled?("START_CONSUMERS")},
        {{Services.PipelineSummaryAvailableNotifier, []}, enabled?("START_CONSUMERS")},
        feature_provider()
      ])

    children =
      children ++
        [
          {Task.Supervisor, name: GithubNotifier.TaskSupervisor},
          %{id: Cachex, start: {Cachex, :start_link, [:store, []]}},
          %{
            id: FeatureProvider.Cachex,
            start: {Cachex, :start_link, [:feature_provider_cache, []]}
          }
        ]

    Enum.each(children, fn c ->
      Logger.info("Starting: #{inspect(c)}")
    end)

    {:ok, _} = Logger.add_backend(Sentry.LoggerBackend)
    Logger.configure_backend(Sentry.LoggerBackend, include_logger_metadata: true)

    opts = [strategy: :one_for_one, name: GithubNotifier.Supervisor]
    Supervisor.start_link(children, opts)
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
