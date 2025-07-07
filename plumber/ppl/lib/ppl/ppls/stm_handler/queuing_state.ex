defmodule Ppl.Ppls.STMHandler.QueuingState do
  @moduledoc """
  Handles pipelines in queing state and runs them once all older ones from same branch
  are finished.
  """

  alias Ppl.PplTraces.Model.PplTracesQueries
  alias Ppl.TimeLimits.Model.TimeLimitsQueries
  alias Ppl.Ppls.Model.{Ppls, PplsQueries, PplsQueuing}
  alias LogTee, as: LT
  alias Ppl.Ppls.STMHandler.Common

  use Looper.STM,
    id: __MODULE__,
    period_ms: Util.Config.get_sleeping_period(:ppl, :ppl_queuing_sp),
    repo: Ppl.EctoRepo,
    schema: Ppl.Ppls.Model.Ppls,
    observed_state: "queuing",
    allowed_states: ~w(queuing running done),
    cooling_time_sec: Util.Config.get_cooling_time(:ppl, :ppl_queuing_ct),
    columns_to_log: [:state, :result, :recovery_count, :ppl_id],
    publisher_cb: fn params -> Common.publisher_callback(params) end

  def initial_query(), do: Ppls

#######################

  def enter_scheduling(_) do
    with {:ok, [{old, new}]} <- PplsQueuing.queuing_enter_scheduling(),
         true                <- ppl_in_queuing_state(old)
    do
      {:ok, {old, new}}
    else
      {:ok, []}        -> {:ok, {nil, nil}}
      :skip_scheduling -> {:ok, {nil, nil}}
      err              -> err |> LT.error("Error in queuing scheduling")
    end
  end

  defp ppl_in_queuing_state(%{state: "queuing"}), do: true
  defp ppl_in_queuing_state(ppl) do
    ppl |> LT.info("Race in queuing STM, selected pipeline was already processed")
    execute_now()
    :skip_scheduling
  end

#######################

  def terminate_request_handler(ppl, result) when result in ["cancel", "stop"] do
    Common.terminate_pipeline(ppl, "done")
  end
  def terminate_request_handler(_pple, _), do: {:ok, :continue}

#######################

  def scheduling_handler(ppl) do
    case PplsQueries.should_do_auto_cancel?(ppl) do

      {:ok, false} ->
        if ppl.parallel_run do
          handle_run({:ok, "running"}, ppl)
        else
          scheduling_handler_(ppl)
        end

      {:ok, auto_cancel} ->
         Common.do_auto_cancel(ppl, auto_cancel, "done")

      error ->
         {:ok, fn _, _ -> {:error, %{error_description: "#{inspect error}"}} end}
    end
  end

  def scheduling_handler_(ppl) do
    with {:ok, ppls_list} <- PplsQueries.ppls_from_same_queue_in_states(ppl,
                                    ["pending", "queuing", "running"]),
         {:ok, 0}  <- empty_list_or_back_to_queuing(ppls_list)
    do handle_run({:ok, "running"}, ppl)
    else
      e  -> handle_run(e, ppl)
    end
  end

  defp empty_list_or_back_to_queuing([]), do: {:ok, 0}
  defp empty_list_or_back_to_queuing(_), do: {:ok, "queuing"}

  defp set_time_limit(ppl = %{exec_time_limit_min: limit})
  when is_integer(limit) and limit > 0 do
    TimeLimitsQueries.set_time_limit(ppl, "pipeline")
  end
  defp set_time_limit(_ppl_blk), do: {:ok, :continue}

  defp handle_run({:ok, "running"}, ppl) do
    with {:ok, _ptr} <- PplTracesQueries.set_timestamp(ppl.ppl_id, :running_at),
         {:ok, _tl}  <- set_time_limit(ppl)
    do
      {:ok, fn _, _ -> {:ok, %{state: "running"}} end}
    else
      error -> {:ok, fn _, _ -> {:error, %{description: "#{inspect error}"}} end}
    end
  end

  defp handle_run({:ok, "queuing"}, _ppl) do
    {:ok, fn _, _ -> {:ok, %{state: "queuing"}} end}
  end

  defp handle_run(error, _ppl) do
    desc = "#{inspect error}"
    {:ok, fn _, _ -> {:error, %{description: desc}} end}
  end

#######################

  def epilogue_handler({:ok, data = %{user_exit_function: %{state: "running"}}}) do
    Common.trigger_ppl_block_loopers(data)
  end
  def epilogue_handler({:ok, data = %{user_exit_function: %{state: "done"}}}) do
    Common.trigger_ppl_block_loopers(data)
    Common.pipeline_done(data)
  end
  def epilogue_handler(_exit_state), do: :nothing
end
