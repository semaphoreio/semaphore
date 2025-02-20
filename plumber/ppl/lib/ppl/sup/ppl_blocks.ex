defmodule Ppl.Sup.PplBlocks do
  @moduledoc """
  Supervisor for pipeline blocks loopers
  """

  use Supervisor

  alias Ppl.PplBlocks.Beholder, as: PplBlocksBeholder
  alias Ppl.PplBlocks.StateWatch, as: PplBlocksStateWatch
  alias Ppl.PplBlocks.STMHandler

  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  def init(_arg) do
    Supervisor.init([
      PplBlocksBeholder,
      PplBlocksStateWatch,
      STMHandler.InitializingState,
      STMHandler.WaitingState,
      STMHandler.RunningState,
      STMHandler.StoppingState
    ], strategy: :one_for_one)
  end

end
