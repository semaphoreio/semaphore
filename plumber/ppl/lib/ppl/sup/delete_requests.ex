defmodule Ppl.Sup.DeleteRequests do
  @moduledoc """
  Supervisor for delete request loopers
  """

  use Supervisor

  alias Ppl.DeleteRequests.Beholder, as: DeleteRequestsBeholder
  alias Ppl.DeleteRequests.StateWatch, as: DeleteRequestsStateWatch
  alias Ppl.DeleteRequests.STMHandler

  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  def init(_arg) do
    Supervisor.init([
      DeleteRequestsBeholder,
      DeleteRequestsStateWatch,
      STMHandler.PendingState,
      STMHandler.DeletingState,
      STMHandler.QueueDeletingState
    ], strategy: :one_for_one)
  end

end
