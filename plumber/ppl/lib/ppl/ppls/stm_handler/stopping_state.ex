defmodule Ppl.Ppls.STMHandler.StoppingState do
  @moduledoc """
  Handles pipelines in stopping state

  Since pipeline service is a system with eventual consistency, there can be case where
  all blocks passed or some of them failed for what ever reason before they received
  propagated termination request which was sent when pipeline was transitioning from
  'running' to 'stopping',

  Even in those cases, the result of pipeline's execution should still be 'stopped',
  because the user actions are regarded as 'higher truth', and pipeline can only wind up
  in 'stopping' state if there was a termination request (and it was a 'stop')
  from above initiated by either user directly or indirectly via cancellation strategy.

  Because of all of this, it is sufficient to only check if all corresponding
  PplBlocks for Pipeline which is being scheduled are in 'done' state before
  sending it from 'stopping' to 'done' state.
  """

  alias Ppl.PplRequests.Model.PplRequestsQueries
  alias Ppl.Ppls.Model.Ppls
  alias Ppl.PplBlocks.Model.PplBlocksQueries
  alias Ppl.PplTraces.Model.PplTracesQueries
  alias Ppl.TimeLimits.Model.TimeLimitsQueries
  alias Ppl.Ppls.STMHandler.Common
  alias Util.Metrics

  use Looper.STM,
    id: __MODULE__,
    period_ms: Util.Config.get_sleeping_period(:ppl, :ppl_stopping_sp),
    repo: Ppl.EctoRepo,
    schema: Ppl.Ppls.Model.Ppls,
    observed_state: "stopping",
    allowed_states: ~w(stopping done),
    cooling_time_sec: Util.Config.get_cooling_time(:ppl, :ppl_stopping_ct),
    columns_to_log: [:state, :result, :recovery_count, :ppl_id],
    publisher_cb: fn params -> Common.publisher_callback(params) end

  def initial_query(), do: Ppls

#######################

  def terminate_request_handler(_ppl, _), do: {:ok, :continue}

#######################

  def scheduling_handler(ppl) do
    with {:ok, ppl_req}  <- PplRequestsQueries.get_by_id(ppl.ppl_id),
         resp = {:ok, _ppl_status} <- get_status(ppl, ppl_req.block_count)
    do handle_stopping(resp, ppl)
    else
      e -> handle_stopping(e, ppl)
    end
  end

  defp get_status(ppl, block_count) do
    ppl.ppl_id
    |> PplBlocksQueries.all_blocks_done?(block_count)
    |> determin_status()
  end

  defp determin_status(false), do: {:ok, "stopping"}
  defp determin_status(true), do: {:ok, {"done", "stopped"}}

  defp handle_stopping({:ok, {"done", "stopped"}}, ppl) do
    reason = determin_reason(ppl)
    PplTracesQueries.set_timestamp(ppl.ppl_id, :done_at)
    {:ok, fn _, _ -> {:ok, %{state: "done", result: "stopped", result_reason: reason}}end}
  end

  defp handle_stopping({:ok, "stopping"}, _ppl) do
    {:ok, fn _, _ -> {:ok, %{state: "stopping"}} end}
  end

  defp handle_stopping(error, _ppl) do
    desc = %{error: "#{inspect error}"}
    {:ok, fn _, _ -> {:error, %{description: desc}} end}
  end

  defp determin_reason(%{terminate_request_desc: "API call"}), do: "user"
  defp determin_reason(%{terminate_request_desc: "strategy"}), do: "strategy"
  defp determin_reason(%{terminate_request_desc: "time_limit_exceeded"}), do: "timeout"
  defp determin_reason(_), do: "internal"

#######################

  def epilogue_handler({:ok,  data = %{user_exit_function: %{result_reason: "timeout"}}}) do
    ppl_id = data.exit_transition.ppl_id
    {:ok, tl} = TimeLimitsQueries.get_by_id(ppl_id)
    {:ok, tr} = PplTracesQueries.get_by_id(ppl_id)

    diff = DateTime.diff(tr.done_at, tl.deadline, :millisecond)
    {"Ppl.ppl_timeout_overhead", [Metrics.dot2dash(__MODULE__)]} |> Watchman.submit(diff, :timing)

    data |> Common.pipeline_done
  end
  def epilogue_handler({:ok,  data = %{user_exit_function: %{state: "done"}}}) do
    data |> Common.pipeline_done
  end
  def epilogue_handler(_exit_state), do: :nothing
end
