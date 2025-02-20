defmodule Block.Sup.Task do
  @moduledoc """
  Supervisor for pipeline events loopers
  """

  use Supervisor

  alias Block.Tasks.Beholder, as: TasksBeholder
  alias Block.Tasks.StateWatch, as: TasksStateWatch
  alias Block.Tasks.StateResidency, as: TasksStateResidency
  alias Block.Tasks.STMHandler

  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  def init(_arg) do
    Supervisor.init([
      TasksBeholder,
      TasksStateWatch,
      TasksStateResidency,
      STMHandler.PendingState,
      STMHandler.RunningState,
      STMHandler.StoppingState
    ], strategy: :one_for_one)
  end

end
