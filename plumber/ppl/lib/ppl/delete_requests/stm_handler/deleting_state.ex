defmodule Ppl.DeleteRequests.STMHandler.DeletingState do
  @moduledoc """
  Handles  pipeline's deletion
  """

  alias Ppl.DeleteRequests.Model.DeleteRequests
  alias Ppl.PplRequests.Model.PplRequestsQueries
  alias Ppl.Ppls.Model.PplsQueries
  alias LogTee, as: LT

  import Ecto.Query

  use Looper.STM,
    id: __MODULE__,
    period_ms: Util.Config.get_sleeping_period(:ppl, :dr_deleting_sp),
    repo: Ppl.EctoRepo,
    schema: Ppl.DeleteRequests.Model.DeleteRequests,
    observed_state: "deleting",
    allowed_states: ~w(deleting queue_deleting done),
    cooling_time_sec: Util.Config.get_cooling_time(:ppl, :dr_deleting_ct),
    columns_to_log: [:state, :recovery_count, :project_id]

  def initial_query() do
     deletion_offset_h = Util.Config.get_cooling_time(:ppl, :deletion_offset_h)
     DeleteRequests
     |> where([dr], dr.inserted_at < datetime_add(^now_naive(), ^(-deletion_offset_h), "hour"))
  end

  def now_naive(), do: DateTime.utc_now() |> DateTime.to_naive()

  #######################

  def terminate_request_handler(_dr, _), do: {:ok, :continue}

  #######################

  def scheduling_handler(dr) do
    with {:ok, ppl}      <- PplsQueries.get_one_from_project(dr.project_id),
         {:ok, _message} <- Block.delete_blocks_from_ppl(ppl.ppl_id),
         {:ok, _no}      <- PplRequestsQueries.delete_pipeline(ppl.ppl_id)
    do
      dr.project_id |> LT.info("Deleted pipeline #{ppl.ppl_id} from project:")
      to_state("deleting")
    else
      {:error, {:ppl_not_found, _m}} -> to_state("queue_deleting")

      {:error, message} -> to_done("failed", "internal", message)
      error -> to_done("failed", "internal", error)
    end
  end

  defp to_state(state, additional_params \\ %{}) do
    {:ok, fn _, _ -> {:ok, %{state: state} |> Map.merge(additional_params)} end}
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
