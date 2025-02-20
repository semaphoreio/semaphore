defmodule Ppl.AfterPplTasks.STMHandler.WaitingState do
  @moduledoc """
  Initial state.
  Waiting state transition for AfterPplTasks.
  Transitions to pending state as soon as pipeline is in `done` state.
  """

  alias Ppl.AfterPplTasks.Model.AfterPplTasks
  alias Ppl.Ppls.Model.PplsQueries
  alias Ppl.AfterPplTasks.STMHandler.Common
  import Ecto.Query

  use Looper.STM,
    id: __MODULE__,
    period_ms: Util.Config.get_sleeping_period(:ppl, :ppl_after_task_waiting_sp),
    repo: Ppl.EctoRepo,
    schema: AfterPplTasks,
    observed_state: "waiting",
    allowed_states: ~w(waiting pending done),
    cooling_time_sec: Util.Config.get_cooling_time(:ppl, :ppl_after_task_waiting_ct),
    publisher_cb: fn params -> Common.publisher_callback(params) end,
    columns_to_log: [:state, :ppl_id]

  def initial_query(), do: from(AfterPplTasks)

  #######################

  def scheduling_handler(after_ppl_task) do
    case PplsQueries.get_by_id(after_ppl_task.ppl_id) do
      {:ok, ppl} ->
        ppl.state
        |> case do
          "done" -> {:ok, fn _, _ -> {:ok, %{state: "pending"}} end}
          _ -> {:ok, fn _, _ -> {:ok, %{state: "waiting"}} end}
        end
      error -> handle_error(error)
    end
  end

  def terminate_request_handler(_after_ppl_task, _), do: {:ok, :continue}

  defp handle_error(e = {:error, _error}), do: {:ok, fn _, _ -> e end}
  defp handle_error(error), do: {:ok, fn _, _ -> {:error, error} end}
end
