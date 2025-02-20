defmodule Ppl.Sup.Ppls do
  @moduledoc """
  Supervisor for pipelines loopers
  """

  use Supervisor

  alias Ppl.Ppls.Beholder, as: PplsBeholder
  alias Ppl.Ppls.StateWatch, as: PplsStateWatch
  alias Ppl.Ppls.StateResidency, as: PplsStateResidency
  alias Ppl.Ppls.STMHandler

  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  def init(_arg) do
    Supervisor.init([
      PplsBeholder,
      PplsStateWatch,
      PplsStateResidency,
      {Task.Supervisor, name: PplsTaskSupervisor},
      STMHandler.InitializingState,
      STMHandler.PendingState,
      STMHandler.QueuingState,
      STMHandler.RunningState,
      STMHandler.StoppingState,
    ], strategy: :one_for_one)
  end

end
