defmodule Block.Sup.STM do
  @moduledoc """
  Supervisor for all STM supervisors
  """

  use Supervisor

  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  def init(_arg) do
    Supervisor.init([
      Block.Sup.Blk,
      Block.Sup.Task,
    ], strategy: :one_for_one)
  end
end
