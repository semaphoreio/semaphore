defmodule Dashboardhub.Application do
  use Application
  require Logger

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    Logger.info("Running application in #{get_env()} environment")

    # Disables too verbose logging from amqp supervisors
    :logger.add_primary_filter(
      :ignore_rabbitmq_progress_reports,
      {&:logger_filters.domain/2, {:stop, :equal, [:progress]}}
    )

    grpc_port = Application.get_env(:dashboardhub, :grpc_port)

    children =
      filter_enabled([
        {{GRPC.Server.Supervisor,
          endpoint: Dashboardhub.Grpc.Endpoint, port: grpc_port, start_server: true},
         enabled?("GRPC_API", true)},
        {{Task.Supervisor, name: Dashboardhub.SentryEventSupervisor}, true},
        {{Dashboardhub.Repo, []}, true}
      ])

    Enum.each(children, fn c ->
      Logger.info("Starting: #{inspect(c)}")
    end)

    if get_env() == :prod do
      {:ok, _} = Logger.add_backend(Sentry.LoggerBackend)
    end

    opts = [strategy: :one_for_one, name: Dashboardhub.Supervisor]
    Supervisor.start_link(children, opts)
  end

  def enabled?(env_var, force_in_test \\ false) do
    (force_in_test && get_env() == :test) ||
      System.get_env(env_var) == "true"
  end

  def filter_enabled(list) do
    list
    |> Enum.filter(fn e -> elem(e, 1) end)
    |> Enum.map(fn e -> elem(e, 0) end)
  end

  defp get_env do
    Application.fetch_env!(:dashboardhub, :environment)
  end
end
