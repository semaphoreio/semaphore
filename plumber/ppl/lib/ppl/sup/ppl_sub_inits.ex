defmodule Ppl.Sup.PplSubInits do
  @moduledoc """
  Supervisor for pipeline sub init loopers
  """

  use Supervisor

  alias Ppl.PplSubInits.Beholder, as: SubInitBeholder
  alias Ppl.PplSubInits.StateWatch, as: SubInitStateWatch
  alias Ppl.PplSubInits.STMHandler

  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  def init(_arg) do
    Supervisor.init([
      SubInitBeholder,
      SubInitStateWatch,
      STMHandler.ConceivedState,
      STMHandler.CreatedState,
      STMHandler.FetchingState,
      STMHandler.CompilationState,
      STMHandler.StoppingState,
      STMHandler.RegularInitState
    ], strategy: :one_for_one)
  end

end
