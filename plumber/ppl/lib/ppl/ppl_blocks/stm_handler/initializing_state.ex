defmodule Ppl.PplBlocks.STMHandler.InitializingState do
  @moduledoc """
  Handles initializing of Ppl Blocks
  """
  alias Ppl.PplBlocks.Model.{PplBlocks, PplBlocksQueries}
  alias Ppl.Ppls.Model.PplsQueries
  alias Ppl.PplBlocks.STMHandler.Common

  use Looper.STM,
    id: __MODULE__,
    period_ms: Util.Config.get_sleeping_period(:ppl, :ppl_blk_initializing_sp),
    repo: Ppl.EctoRepo,
    schema: Ppl.PplBlocks.Model.PplBlocks,
    observed_state: "initializing",
    allowed_states: ~w(initializing waiting done),
    cooling_time_sec: Util.Config.get_cooling_time(:ppl, :ppl_blk_initializing_ct),
    columns_to_log: [:state, :result, :recovery_count, :ppl_id, :block_index]

  def initial_query(), do: PplBlocks

#######################

  def terminate_request_handler(ppl_blk, result) when result in ["cancel", "stop"] do
    reason = Common.determin_reason(ppl_blk)
    {:ok, fn _, _ -> {:ok, %{state: "done", result: "canceled", result_reason: reason}} end}
  end
  def terminate_request_handler(_ppl_blk, _), do: {:ok, :continue}

#######################

  def scheduling_handler(ppl_blk) do
    case PplBlocksQueries.should_do_fast_failing?(ppl_blk) do
      {:ok, false} ->
         scheduling_handler_(ppl_blk)
      {:ok, ff_strategy} ->
         Common.do_fast_failing(ppl_blk, ff_strategy, "initializing")
      error ->
         {:ok, fn _, _ -> {:error, %{error_description: "#{inspect error}"}} end}
    end
  end

  def scheduling_handler_(ppl_blk) do
    if ppl_blk.duplicate do
      duplicate_ppl_block(ppl_blk)
    else
      {:ok, fn _, _ -> {:ok, %{state: "waiting"}} end}
    end
  end

  defp duplicate_ppl_block(ppl_blk) do
    with {:ok, ppl}          <- PplsQueries.get_by_id(ppl_blk.ppl_id),
         orig_ppl_id         <- ppl.partial_rebuild_of,
         {:ok, orig_ppl_blk} <- PplBlocksQueries.get_by_id_and_index(
                                             orig_ppl_id, ppl_blk.block_index)
    do
       rebuild_or_duplicate_block(orig_ppl_blk, ppl_blk.ppl_id)
    else
      error ->
         {:ok, fn _, _ -> {:error, %{error_description: "#{inspect error}"}} end}
    end
  end

  defp rebuild_or_duplicate_block(orig_ppl_blk = %{block_id: nil, state: "done", result: "passed", result_reason: "skipped"}, new_ppl_id) do
    {:ok, fn _, _ -> {:ok, %{state: "done", result: "passed", result_reason: "skipped"}} end}
  end

  defp rebuild_or_duplicate_block(orig_ppl_blk = %{state: "done", result: "passed"}, new_ppl_id) do
    case  Block.duplicate(orig_ppl_blk.block_id, new_ppl_id) do
      {:ok, new_block_id} ->
          {:ok, fn _, _ -> {:ok, %{state: "done", result: "passed", block_id: new_block_id}} end}

      error ->
         {:ok, fn _, _ -> {:error, %{error_description: "#{inspect error}"}} end}
    end
  end
  defp rebuild_or_duplicate_block(_orig_ppl_blk, _new_ppl_id) do
    {:ok, fn _, _ -> {:ok, %{state: "waiting"}} end}
  end

#######################

  def epilogue_handler({:ok, data = %{user_exit_function: %{state: "done"}}}) do
    Common.notify_ppl_when_done(data)
    data |> Map.get(:user_exit_function) |> Common.send_state_watch_metric()
  end
  def epilogue_handler(_exit_state), do: :nothing
end
