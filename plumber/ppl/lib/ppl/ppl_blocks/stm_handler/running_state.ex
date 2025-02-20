defmodule Ppl.PplBlocks.STMHandler.RunningState do
  @moduledoc """
  Handles describing pipeline's blocks
  """

  alias Ppl.PplBlocks.Model.{PplBlocks, PplBlocksQueries}
  alias Ppl.PplBlocks.STMHandler.Common
  alias Ppl.Ppls.STMHandler.Common, as: PplsCommon
  alias Ppl.TimeLimits.Model.TimeLimitsQueries

  use Looper.STM,
    id: __MODULE__,
    period_ms: 1_000,
    repo: Ppl.EctoRepo,
    schema: Ppl.PplBlocks.Model.PplBlocks,
    observed_state: "running",
    allowed_states: ~w(running stopping done),
    cooling_time_sec: Util.Config.get_cooling_time(:ppl, :ppl_blk_running_ct),
    columns_to_log: [:state, :result, :recovery_count, :ppl_id, :block_index, :block_id],
    publisher_cb: fn params -> Common.publisher_callback(params) end

  def initial_query(), do: PplBlocks

#######################

  def terminate_request_handler(ppl_blk, "stop") do
    with {:ok, _tl}      <- terminate_time_limit(ppl_blk),
         {:ok, _message} <- Block.terminate(ppl_blk.block_id)
    do
      {:ok, fn _, _ -> {:ok, %{state: "stopping"}} end}
    else
      error -> {:ok, fn _, _ -> {:error, %{error_description: "#{inspect error}"}} end}
    end
  end
  def terminate_request_handler(_ppl_blk, _), do: {:ok, :continue}

  defp terminate_time_limit(blk) do
    case TimeLimitsQueries.get_by_id_and_index(blk.ppl_id, blk.block_index) do
      {:ok, tl} -> terminate_time_limit_(blk, tl)

      {:error, "Time limit for block " <> _rest} -> {:ok, :continue}

      error -> error
    end
  end

  defp terminate_time_limit_(_blk, %{terminate_request: val})
    when is_binary(val) and val != "", do: {:ok, :continue}

  defp terminate_time_limit_(blk, tl) do
    TimeLimitsQueries.terminate(tl, blk.terminate_request, blk.terminate_request_desc)
  end

#######################

  def scheduling_handler(ppl_blk) do
    case PplBlocksQueries.should_do_fast_failing?(ppl_blk) do
      {:ok, "stop"} ->
        Common.do_fast_failing(ppl_blk, "stop", "running")
      {:ok, ff_strategy} when ff_strategy in ["cancel", false] ->
        scheduling_handler_(ppl_blk)
      error ->
         {:ok, fn _, _ -> {:error, %{error_description: "#{inspect error}"}} end}
    end
  end

  def scheduling_handler_(ppl_blk) do
    ppl_blk.block_id
    |> Block.status()
    |> handle_status_check(ppl_blk)
  end

  defp handle_status_check({:ok, block_status}, _ppl_blk) do
    %{state: state, result: result, result_reason: result_reason} = block_status
    determin_state_transition({state, result, result_reason})
  end

  defp handle_status_check({:error, msg}, _ppl_blk) do
    error_desc = "#{inspect msg}"
    {:ok, fn _, _ -> {:error, %{error_description: error_desc}} end}
  end

  defp determin_state_transition({"initializing", _, _}),
    do: {:ok, fn _, _ -> {:ok, %{state: "running"}} end}

  defp determin_state_transition({"running", _, _}),
    do: {:ok, fn _, _ -> {:ok, %{state: "running"}} end}

  defp determin_state_transition({"done", result, result_reason}) when is_nil(result_reason),
    do: {:ok, fn _, _ -> {:ok, %{state: "done", result: result}} end}

  defp determin_state_transition({"done", result, result_reason}),
    do: {:ok, fn _, _ -> {:ok, %{state: "done", result: result, result_reason: result_reason}} end}

  defp determin_state_transition(error) do
    error_desc = "#{inspect error}"
    {:ok, fn _, _ -> {:error, %{error_description: error_desc}} end}
  end

#######################

  def epilogue_handler({:ok, data = %{user_exit_function: %{state: "done"}}}) do
    PplsCommon.trigger_ppl_block_loopers(data)
    Common.notify_ppl_when_done(data)
    Common.send_metrics(data, __MODULE__)
    data |> Map.get(:user_exit_function) |> Common.send_state_watch_metric()
  end
  def epilogue_handler(_exit_state), do: :nothing
end
