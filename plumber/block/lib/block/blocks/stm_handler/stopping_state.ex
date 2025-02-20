defmodule Block.Blocks.STMHandler.StoppingState do
  @moduledoc """
  Handles stopping blocks
  """

  use Looper.STM,
    id: __MODULE__,
    period_ms: Util.Config.get_sleeping_period(:block, :blk_stopping_sp),
    repo: Block.EctoRepo,
    schema: Block.Blocks.Model.Blocks,
    observed_state: "stopping",
    allowed_states: ~w(stopping done),
    cooling_time_sec: Util.Config.get_cooling_time(:block, :blk_stopping_ct),
    columns_to_log: [:state, :recovery_count, :block_id]

  alias Block.Tasks.Model.TasksQueries
  alias Block.Blocks.Model.Blocks
  alias Block.Blocks.STMHandler.Common

  def initial_query(), do: Blocks

  def terminate_request_handler(_blke, _), do: {:ok, :continue}

  def scheduling_handler(blk) do
    blk.block_id
    |> TasksQueries.get_by_id()
    |> determin_state_transition(blk)
  end

  defp determin_state_transition({:ok, %{state: "done"}}, blke) do
    reason = determin_reason(blke)
    {:ok, fn _, _ -> {:ok, %{state: "done", result: "stopped", result_reason: reason}} end}
  end

  defp determin_state_transition({:ok, _task}, _blk),
    do: {:ok, fn _, _ -> {:ok, %{state: "stopping"}} end}

  defp determin_state_transition({:error, msg}, _blk) do
    error_desc = "Error: #{inspect msg}"
    {:ok, fn _, _ -> {:error, %{error_description: error_desc}} end}
  end

  defp determin_reason(%{terminate_request_desc: "API call"}), do: "user"
  defp determin_reason(%{terminate_request_desc: "strategy"}), do: "strategy"
  defp determin_reason(_), do: "internal"

  def epilogue_handler({:ok, data = %{user_exit_function: %{state: "done"}}}) do
    Common.notify_ppl_block_when_done(data)
    Common.send_metrics(data, __MODULE__)
    data |> Map.get(:user_exit_function) |> Common.send_state_watch_metric()
  end
  def epilogue_handler(_exit_state), do: :nothing
end
