defmodule Ppl.Ppls.STMHandler.RunningState do
  @moduledoc """
  Handles describing pipelines
  """

  alias Ppl.PplRequests.Model.PplRequestsQueries
  alias Ppl.PplTraces.Model.PplTracesQueries
  alias Ppl.Ppls.Model.{Ppls, PplsQueries}
  alias Ppl.PplBlocks.Model.PplBlocksQueries
  alias Ppl.Ppls.STMHandler.Common

  use Looper.STM,
    id: __MODULE__,
    period_ms: Util.Config.get_sleeping_period(:ppl, :ppl_running_sp),
    repo: Ppl.EctoRepo,
    schema: Ppl.Ppls.Model.Ppls,
    observed_state: "running",
    allowed_states: ~w(running stopping done),
    cooling_time_sec: Util.Config.get_cooling_time(:ppl, :ppl_running_ct),
    columns_to_log: [:state, :result, :recovery_count, :ppl_id],
    publisher_cb: fn params -> Common.publisher_callback(params) end,
    task_supervisor: PplsTaskSupervisor

  def initial_query(), do: Ppls

#######################

  def terminate_request_handler(ppl, "stop") do
    Common.terminate_pipeline(ppl, "stopping")
  end
  def terminate_request_handler(_ppl, _), do: {:ok, :continue}

#######################

  def scheduling_handler(ppl) do
    case PplsQueries.should_do_auto_cancel?(ppl) do
      {:ok, "stop"} ->
         Common.do_auto_cancel(ppl, "stop", "stopping")
      {:ok, ac_strategy} when ac_strategy in ["cancel", false] ->
         scheduling_handler_(ppl)
      error ->
         {:ok, fn _, _ -> {:error, %{error_description: "#{inspect error}"}} end}
    end
  end

  def scheduling_handler_(ppl) do
    with {:ok, ppl_req}   <- PplRequestsQueries.get_by_id(ppl.ppl_id),
         resp = {:ok, _ppl_status} <- get_status(ppl, ppl_req.block_count)
    do handle_describe(resp, ppl)
    else
      e -> handle_describe(e, ppl)
    end
  end

  defp get_status(ppl, block_count) do
    ppl.ppl_id
    |> PplBlocksQueries.all_blocks_done?(block_count)
    |> all_done?(ppl, block_count)
  end

  defp all_done?(false, _, _), do: {:ok, "running"}
  defp all_done?(true, ppl, block_count) do
    ppl.ppl_id
    |> PplBlocksQueries.all_blocks_done?(block_count, "passed")
    |> all_passed?(ppl)
  end

  defp all_passed?(true, _ppl), do: {:ok, {"done", "passed"}}
  defp all_passed?(false, ppl) do
    {result, reason} =
      PplBlocksQueries.get_first_not_passed_block_result_and_reason(ppl.ppl_id)
    {:ok, {"done", result, reason}}
  end

  defp handle_describe(scheduling_result, ppl, additional_params \\ %{})

  defp handle_describe({:ok, {"done", result}}, ppl, _additional_params) do
    PplTracesQueries.set_timestamp(ppl.ppl_id, :done_at)
    {:ok, fn _, _ -> {:ok, %{state: "done", result: result}}end}
  end

  defp handle_describe({:ok, {"done", result, reason}}, ppl, _additional_params) do
    PplTracesQueries.set_timestamp(ppl.ppl_id, :done_at)
    {:ok, fn _, _ -> {:ok, %{state: "done", result: result, result_reason: reason}} end}
  end

  defp handle_describe({:ok, "running"}, _ppl, additional_params) do
    {:ok, fn _, _ -> {:ok, %{state: "running"} |> Map.merge(additional_params)} end}
  end

  defp handle_describe(error, _ppl, _additional_params) do
    desc = %{error: "#{inspect error}"}
    {:ok, fn _, _ -> {:error, %{description: desc}} end}
  end

#######################

  def epilogue_handler({:ok,  data = %{user_exit_function: %{state: "done"}}}) do
    Common.pipeline_done(data)
  end
  def epilogue_handler({:ok, data = %{user_exit_function: %{state: "stopping"}}}) do
    Common.trigger_ppl_block_loopers(data)
  end
  def epilogue_handler(_exit_state), do: :nothing
end
