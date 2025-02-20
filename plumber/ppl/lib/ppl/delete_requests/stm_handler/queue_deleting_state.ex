defmodule Ppl.DeleteRequests.STMHandler.QueueDeletingState do
  @moduledoc """
  Handles  queues's deletion
  """

  alias Ppl.DeleteRequests.Model.DeleteRequests
  alias Ppl.Queues.Model.QueuesQueries
  alias LogTee, as: LT

  use Looper.STM,
    id: __MODULE__,
    period_ms: Util.Config.get_sleeping_period(:ppl, :dr_queue_deleting_sp),
    repo: Ppl.EctoRepo,
    schema: Ppl.DeleteRequests.Model.DeleteRequests,
    observed_state: "queue_deleting",
    allowed_states: ~w(queue_deleting done),
    cooling_time_sec: Util.Config.get_cooling_time(:ppl, :dr_queue_deleting_ct),
    columns_to_log: [:state, :recovery_count, :project_id]

  def initial_query(), do: DeleteRequests

  #######################

  def terminate_request_handler(_dr, _), do: {:ok, :continue}

  #######################

  def scheduling_handler(dr) do
    with {:ok, queue} <- QueuesQueries.get_one_project_scoped(dr.project_id),
         {:ok, _no}   <- QueuesQueries.delete_queue(queue.queue_id)
    do
      dr.project_id |> LT.info("Deleted queue #{queue.name} from project:")
      to_state("queue_deleting")
    else
      {:error, {:queue_not_found, _m}} -> to_done("passed")

      {:error, message} -> to_done("failed", "internal", message)
      error -> to_done("failed", "internal", error)
    end
  end

  defp to_state(state, additional_params \\ %{}) do
    {:ok, fn _, _ -> {:ok, %{state: state} |> Map.merge(additional_params)} end}
  end

  defp to_done(result) do
    to_state("done", %{result: result})
  end

  defp to_done(result, result_reason, error) when not is_binary(error),
    do: to_done(result, result_reason, "#{inspect error}")

  defp to_done(result, result_reason, error_desc) do
    "done"
    |> to_state(%{result: result, result_reason: result_reason,
                  error_description: error_desc})
  end

  #######################

  def epilogue_handler(_exit_state), do: :nothing
end
