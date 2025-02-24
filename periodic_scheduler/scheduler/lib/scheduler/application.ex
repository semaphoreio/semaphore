defmodule Scheduler.Application do
  @moduledoc """
  The main OTP Application for the Scheduler service.
  Handles startup of all components including repositories, gRPC servers, and workers.
  """

  use Application

  def start(_type, _args) do
    Application.stop(:watchman)
    Application.ensure_all_started(:watchman)

    provider = Application.fetch_env!(:scheduler, :feature_provider)
    FeatureProvider.init(provider)

    opts = [strategy: :one_for_one, name: Scheduler.Supervisor]
    get_env() |> children() |> Supervisor.start_link(opts)
  end

  def children(:test) do
    [
      {Scheduler.PeriodicsRepo, []},
      {Scheduler.FrontRepo, []},
      {GRPC.Server.Supervisor,
       {[Scheduler.Grpc.Server, Scheduler.Grpc.HealthCheck.Server],
        Application.get_env(:scheduler, :grpc_port, 50_050)}},
      Scheduler.Workers.ScheduleTaskManager,
      Supervisor.child_spec(
        {Cachex, name: Scheduler.FeatureHubProvider},
        id: :feature_cache
      )
    ]
  end

  def children(_), do: Enum.concat(children(:test), children_())

  def children_() do
    [
      Scheduler.Workers.QuantumScheduler,
      Scheduler.Workers.Initializer,
      {Scheduler.EventsConsumers.OrgBlocked, []},
      {Scheduler.EventsConsumers.OrgUnblocked, []}
    ]
  end

  defp get_env(), do: Application.get_env(:scheduler, :mix_env)
end
