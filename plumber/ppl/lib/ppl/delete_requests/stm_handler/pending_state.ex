defmodule Ppl.DeleteRequests.STMHandler.PendingState do
  @moduledoc """
  Handles initializing of pipelines deletion
  """

  alias Ppl.DeleteRequests.Model.DeleteRequests
  alias Ppl.Ppls.Model.PplsQueries
  alias Util.ToTuple

  use Looper.STM,
    id: __MODULE__,
    period_ms: Util.Config.get_sleeping_period(:ppl, :dr_pending_sp),
    repo: Ppl.EctoRepo,
    schema: Ppl.DeleteRequests.Model.DeleteRequests,
    observed_state: "pending",
    allowed_states: ~w(deleting done),
    cooling_time_sec: Util.Config.get_cooling_time(:ppl, :dr_pending_ct),
    columns_to_log: [:state, :recovery_count, :project_id]

  @not_done_ppl_states ~w(initializing pending queuing running)

  def initial_query(), do: DeleteRequests

  #######################

  def terminate_request_handler(_dr, _), do: {:ok, :continue}

  #######################

  def scheduling_handler(dr) do
    with {:ok, params}     <- termination_params(dr.project_id, dr.requester),
         {:ok, _n_updated} <- PplsQueries.terminate_all(params),
         {:ok, ppls_no}    <- PplsQueries.no_of_ppls_from_project_in_states(
                                              dr.project_id, @not_done_ppl_states),
         {:ok, :continue}  <- continue_or_wait_for_termination(ppls_no)
    do
      to_state("deleting")
    else
      :wait_for_ppls_termination -> to_state("pending")
      {:error, message} -> to_done("failed", "internal", message)
      error -> to_done("failed", "internal", error)
    end
  end

  defp continue_or_wait_for_termination(0), do: {:ok, :continue}
  defp continue_or_wait_for_termination(_n), do: :wait_for_ppls_termination

  defp termination_params(project_id, terminated_by) do
    %{project_id: project_id,
      terminate_request: "stop",
      terminate_request_desc: "API call",
      terminated_by: terminated_by
     } |> ToTuple.ok()
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
