defmodule PreFlightChecks.Application do
  @moduledoc false
  use Application

  def start(_type, _args) do
    children = [
      PreFlightChecks.EctoRepo,
      PreFlightChecks.GRPC,
      PreFlightChecks.Consumers
    ]

    opts = [strategy: :one_for_one, name: PreFlightChecks.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
