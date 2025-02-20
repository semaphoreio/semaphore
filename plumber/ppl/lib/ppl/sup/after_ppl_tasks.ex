defmodule Ppl.Sup.AfterPplTasks do
  @moduledoc """
  Supervisor for after ppl tasks loopers
  """

  use Supervisor

  alias Ppl.AfterPplTasks.Beholder, as: Beholder
  alias Ppl.AfterPplTasks.StateWatch, as: StateWatch
  alias Ppl.AfterPplTasks.STMHandler

  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  def init(_arg) do
    Supervisor.init([
      Beholder,
      StateWatch,
      STMHandler.WaitingState,
      STMHandler.PendingState,
      STMHandler.RunningState,
    ], strategy: :one_for_one)
  end

end
