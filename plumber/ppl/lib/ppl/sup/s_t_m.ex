defmodule Ppl.Sup.STM do
  @moduledoc """
  Supervisor for all STM supervisors
  """

  use Supervisor

  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  def init(_arg) do
    Supervisor.init([
      Ppl.Sup.Ppls,
      Ppl.Sup.PplSubInits,
      Ppl.Sup.PplBlocks,
      Ppl.Sup.TimeLimits,
      Ppl.Sup.DeleteRequests,
      Ppl.Sup.AfterPplTasks,
    ], strategy: :one_for_one)
  end

end
