defmodule PreFlightChecks.Consumers do
  @moduledoc """
    Tackle consumer supervisor
  """

  use Supervisor
  alias PreFlightChecks.Consumers

  def start_link(args) do
    Supervisor.start_link(__MODULE__, args, name: __MODULE__)
  end

  @impl true
  def init(_args) do
    children = [
      Consumers.CleanupConsumer
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
