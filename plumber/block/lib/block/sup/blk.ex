defmodule Block.Sup.Blk do
  @moduledoc """
  Supervisor for blocks loopers
  """

  use Supervisor

  alias Block.Blocks.Beholder, as: BlocksBeholder
  alias Block.Blocks.StateWatch, as: BlocksStateWatch
  alias Block.Blocks.STMHandler

  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  def init(_arg) do
    Supervisor.init([
      BlocksBeholder,
      BlocksStateWatch,
      STMHandler.InitializingState,
      STMHandler.RunningState,
      STMHandler.StoppingState
    ], strategy: :one_for_one)
  end

end
