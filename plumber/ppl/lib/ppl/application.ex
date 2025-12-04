defmodule Ppl.Application do
  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  import Supervisor.Spec, warn: false

  require Logger

  def start(_type, _args) do
    Logger.info("Running plumber in #{get_env()} environment")

    Application.stop(:watchman)
    Application.ensure_all_started(:watchman)

    # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Ppl.Supervisor]
    (children(get_env()) ++ grpc_supervisor(get_env())) |> Supervisor.start_link(opts)
  end

  def children(:test) do
    [
      {Looper.Publisher.AMQP, amqp_url()},
      Supervisor.child_spec({Ppl.Grpc.InFlightCounter, in_flight_counter_args(:describe)}, id: InFlightCounterDescribe),
      Supervisor.child_spec({Ppl.Grpc.InFlightCounter, in_flight_counter_args(:list)}, id: InFlightCounterList),
      supervisor(Ppl.Cache, []),
      supervisor(Ppl.EctoRepo, [])
    ]
  end

  def children(_), do: Enum.concat(children(:test), children_())

  defp grpc_supervisor(env),
    do: [supervisor(GRPC.Server.Supervisor, [{grpc_servers(env), 50_053}])]

  defp grpc_servers(:test),
    do:
      [
        Test.Support.Mocks.UserServer,
        Test.Support.Mocks.PFCServer,
        Test.Support.Mocks.OrgServer
      ] ++ grpc_servers()

  defp grpc_servers(_), do: grpc_servers()

  defp grpc_servers, do: [Ppl.Grpc.Server, Plumber.WorkflowAPI.Server, Ppl.Admin.Server, Ppl.Grpc.HealthCheck]

  def children_ do
    [
      Ppl.Sup.STM,
      worker(Ppl.OrgEventsConsumer, []),
      worker(Ppl.Retention.PolicyConsumer, []),
      worker(Ppl.Retention.RecordDeleter, [])
    ]
  end

  defp get_env, do: Application.get_env(:ppl, :environment)

  defp amqp_url, do: System.get_env("RABBITMQ_URL")

  defp in_flight_counter_args(type), do: [type: type, limit: in_flight_counter_limit(type)]

  defp in_flight_counter_limit(type) do
    up_type = type |> Atom.to_string |> String.upcase

    "IN_FLIGHT_#{up_type}_LIMIT"
    |> System.get_env()
    |> String.to_integer()
  end
end
