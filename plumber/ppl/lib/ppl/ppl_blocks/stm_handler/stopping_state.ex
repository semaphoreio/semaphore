defmodule Ppl.PplBlocks.STMHandler.StoppingState do
  @moduledoc """
  Handles stoping pipeline's blocks
  """

  alias Ppl.PplBlocks.Model.PplBlocks
  alias Ppl.PplBlocks.STMHandler.Common

  use Looper.STM,
    id: __MODULE__,
    period_ms: 1_000,
    repo: Ppl.EctoRepo,
    schema: Ppl.PplBlocks.Model.PplBlocks,
    observed_state: "stopping",
    allowed_states: ~w(stopping done),
    cooling_time_sec: Util.Config.get_cooling_time(:ppl, :ppl_blk_stopping_ct),
    columns_to_log: [:state, :result, :recovery_count, :ppl_id, :block_index, :block_id],
    publisher_cb: fn params -> Common.publisher_callback(params) end

  def initial_query(), do: PplBlocks

  def terminate_request_handler(_ppl_blk, _), do: {:ok, :continue}

  def scheduling_handler(ppl_blk) do
    ppl_blk.block_id
    |> Block.status()
    |> determin_state_transition(ppl_blk)
  end

  defp determin_state_transition({:ok, %{state: "done"}}, ppl_blk) do
    reason = determin_reason(ppl_blk)
    {:ok, fn _, _ -> {:ok, %{state: "done", result: "stopped", result_reason: reason}} end}
  end

  defp determin_state_transition({:ok, _block_status}, _ppl_blk) ,
    do: {:ok, fn _, _ -> {:ok, %{state: "stopping"}} end}

  defp determin_state_transition({:error, msg}, _ppl_blk) do
    error_desc = "#{inspect msg}"
    {:ok, fn _, _ -> {:error, %{error_description: error_desc}} end}
  end

  defp determin_reason(%{terminate_request_desc: "API call"}), do: "user"
  defp determin_reason(%{terminate_request_desc: "strategy"}), do: "strategy"
  defp determin_reason(%{terminate_request_desc: "fast_failing"}), do: "fast_failing"
  defp determin_reason(%{terminate_request_desc: "time_limit_exceeded"}), do: "timeout"
  defp determin_reason(_), do: "internal"

  #######################

  def epilogue_handler({:ok, data = %{user_exit_function: %{state: "done"}}}) do
    Common.notify_ppl_when_done(data)
    Common.send_metrics(data, __MODULE__)
    data |> Map.get(:user_exit_function) |> Common.send_state_watch_metric()
  end
  def epilogue_handler(_exit_state), do: :nothing
end
