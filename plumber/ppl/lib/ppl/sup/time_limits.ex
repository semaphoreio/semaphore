defmodule Ppl.Sup.TimeLimits do
  @moduledoc """
  Supervisor for time limits loopers
  """

  use Supervisor

  alias Ppl.TimeLimits.Beholder
  alias Ppl.TimeLimits.StateWatch
  alias Ppl.TimeLimits.STMHandler

  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  def init(_arg) do
    Supervisor.init([
      Beholder,
      StateWatch,
      STMHandler.PplTrackingState,
      STMHandler.PplBlockTrackingState
    ], strategy: :one_for_one)
  end

end
