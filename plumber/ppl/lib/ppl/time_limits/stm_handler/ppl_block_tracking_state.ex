defmodule Ppl.TimeLimits.STMHandler.PplBlockTrackingState do
  @moduledoc """
  Handles terminating pipeline blocks when time_limt deadline is reached
  """

  import Ecto.Query

  alias Ppl.PplBlocks.Model.PplBlocksQueries
  alias Ppl.PplBlocks.STMHandler.RunningState, as: PplBlockRunningState
  alias Ppl.TimeLimits.Model.{TimeLimits, TrackingStateScheduling}
  alias LogTee, as: LT

  use Looper.STM,
    id: __MODULE__,
    period_ms: Util.Config.get_sleeping_period(:ppl, :tl_tracking_sp),
    repo: Ppl.EctoRepo,
    schema: Ppl.TimeLimits.Model.TimeLimits,
    observed_state: "tracking",
    allowed_states: ~w(done),
    cooling_time_sec: Util.Config.get_cooling_time(:ppl, :tl_tracking_ct),
    columns_to_log: [:state, :result, :recovery_count, :ppl_id, :block_index]

  def initial_query(), do: TimeLimits

#######################
  def enter_scheduling(_) do
    with {:ok, [{old, new}]} <- TrackingStateScheduling.get_deadline_reached("ppl_block"),
         true                <- time_limit_in_tracking_state(old)
    do
      {:ok, {old, new}}
    else
      {:ok, []}   -> {:ok, {nil, nil}}
      :skip_scheduling -> {:ok, {nil, nil}}
      err         -> err |> LT.error("Error in tracking scheduling")
    end
  end

  defp time_limit_in_tracking_state(%{state: "tracking"}), do: true
  defp time_limit_in_tracking_state(tl) do
    tl |> LT.info("Race in tracking STM, selected time_limit was already processed")
    execute_now()
    :skip_scheduling
  end

#######################

  def terminate_request_handler(tl, result) when result in ["cancel", "stop"] do
    reason = determin_reason(tl)
    {:ok, fn _, _ -> {:ok, %{state: "done", result: "canceled", result_reason: reason}} end}
  end
  def terminate_request_handler(_ppl, _), do: {:ok, :continue}

  defp determin_reason(%{terminate_request_desc: "API call"}), do: "user"
  defp determin_reason(%{terminate_request_desc: "strategy"}), do: "strategy"
  defp determin_reason(%{terminate_request_desc: "fast_failing"}), do: "fast_failing"
  defp determin_reason(_), do: "internal"

#######################

  def scheduling_handler(tl) do
    with {:ok, block} <- PplBlocksQueries.get_by_id_and_index(tl.ppl_id, tl.block_index),
         :ok          <- start_termination(block)
    do
      {:ok, fn _, _ -> {:ok, %{state: "done", result: "enforced"}} end}
    else
      {:error, :block_done} ->
        {:ok, fn _, _ -> {:ok, %{state: "done", result: "canceled", result_reason: "ppl_block done"}} end}

      error -> {:ok, fn _, _ -> {:error, %{description: "#{inspect error}"}} end}
    end
  end

  defp start_termination(blk = %{state: "running"}) do
    with {:ok, _blk} <- PplBlocksQueries.terminate(blk, "stop", "time_limit_exceeded"),
         query_fun   <- fn query ->
                         query
                         |> where(ppl_id: ^blk.ppl_id)
                         |> where(block_index: ^blk.block_index)
                       end
    do
      query_fun |> PplBlockRunningState.execute_now_with_predicate()
    end
  end

  defp start_termination(%{state: state})
    when state in ["stopping", "done"], do: {:error, :block_done}

  defp start_termination(error), do: {:error, "Can not terminate #{inspect(error)}"}

#######################

  def epilogue_handler(_exit_state), do: :nothing

end
