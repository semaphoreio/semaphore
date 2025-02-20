defmodule HooksProcessor.Application do
  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  require Logger
  use Application

  @grpc_port 50_050

  alias HooksProcessor.Hooks.Processing.WorkersSupervisor
  alias HooksProcessor.Hooks.Processing.Resurrector
  alias HooksProcessor.Hooks.Grpc.Endpoint, as: GrpcEndpoint
  alias HooksProcessor.HealthCheck
  alias HooksProcessor.Metrics

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    env = get_env()

    Logger.info("Running application in #{env} environment")

    # Disables too verbose logging from amqp supervisors
    :logger.add_primary_filter(
      :ignore_rabbitmq_progress_reports,
      {&:logger_filters.domain/2, {:stop, :equal, [:progress]}}
    )

    children =
      filter_enabled([
        {{GRPC.Server.Supervisor, endpoint: GrpcEndpoint, port: @grpc_port, start_server: true},
         enabled?("START_HOOK_API", true)},
        {{Task.Supervisor, name: HooksProcessor.SentryEventSupervisor}, true},
        {{HooksProcessor.EctoRepo, []}, true},
        {{Registry, [keys: :unique, name: WorkersRegistry]}, enabled?("START_HOOK_WORKERS", true)},
        {{HooksProcessor.RabbitMQConsumer, []}, enabled?("START_HOOK_WORKERS", true)},
        {{Plug.Cowboy, scheme: :http, plug: HealthCheck, options: [port: 4000]}, enabled?("START_HOOK_WORKERS", true)},
        {{WorkersSupervisor, []}, enabled?("START_HOOK_WORKERS")},
        {{Resurrector, []}, enabled?("START_HOOK_WORKERS")},
        {{Metrics, []}, enabled?("START_METRICS")}
      ])

    Enum.each(children, fn c ->
      Logger.info("Starting: #{inspect(c)}")
    end)

    :logger.add_handler(:sentry_handler, Sentry.LoggerHandler, %{})

    opts = [strategy: :one_for_one, name: HooksProcessor.Supervisor]
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

  defp get_env, do: Application.get_env(:hooks_processor, :environment)
end
