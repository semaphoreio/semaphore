defmodule Notifications.Application do
  @moduledoc false
  @grpc_port 50_051

  use Application
  require Logger

  def start(_type, _args) do
    Logger.info("Running application in #{env()} environment")

    # Disables too verbose logging from amqp supervisors
    :logger.add_primary_filter(
      :ignore_rabbitmq_progress_reports,
      {&:logger_filters.domain/2, {:stop, :equal, [:progress]}}
    )

    children =
      [
        Notifications.Repo,
        Notifications.Workers.Coordinator.PipelineFinished,
        Notifications.Workers.Destroyer
      ] ++ grpc_services()

    opts = [strategy: :one_for_one, name: Notifications.Supervisor]

    unless env() in [:dev, :test] do
      {:ok, _} = Logger.add_backend(Sentry.LoggerBackend)
    end

    Enum.each(children, fn c ->
      Logger.info("Starting: #{inspect(c)}")
    end)

    Supervisor.start_link(children, opts)
  end

  defp grpc_services do
    services = public_grpc_api() ++ internal_grpc_api()

    if length(services) > 0 do
      [{GRPC.Server.Supervisor, {services, @grpc_port}}]
    else
      []
    end
  end

  defp public_grpc_api do
    if env() == :test || System.get_env("START_PUBLIC_API") == "true" do
      [Notifications.Api.PublicApi]
    else
      []
    end
  end

  defp internal_grpc_api do
    if env() == :test || System.get_env("START_INTERNAL_API") == "true" do
      [Notifications.Api.InternalApi]
    else
      []
    end
  end

  defp env, do: Application.fetch_env!(:notifications, :environment)
end
