defmodule Block.Blocks.STMHandler.RunningState do
  @moduledoc """
  Handles describing blocks
  For v1 pipelines block state is equal to its task's state
  """

  use Looper.STM,
    id: __MODULE__,
    period_ms: Util.Config.get_sleeping_period(:block, :blk_running_sp),
    repo: Block.EctoRepo,
    schema: Block.Blocks.Model.Blocks,
    observed_state: "running",
    allowed_states: ~w(running stopping done),
    cooling_time_sec: Util.Config.get_cooling_time(:block, :blk_running_ct),
    columns_to_log: [:state, :recovery_count, :block_id]

  alias Block.BlockSubppls.Model.BlockSubpplsQueries
  alias Block.Tasks.Model.TasksQueries
  alias Block.Blocks.Model.Blocks
  alias Block.Blocks.STMHandler.Common
  alias Block.Tasks.STMHandler.RunningState, as: TaskRunningState

  def initial_query(), do: Blocks

  def terminate_request_handler(blk, "stop") do
    with found_task    <- TasksQueries.get_by_id(blk.block_id),
         found_subppls <- BlockSubpplsQueries.get_all_by_id(blk.block_id),
         :ok           <- terminate_existing(found_task, found_subppls, blk)
    do {:ok, fn _, _ -> {:ok, %{state: "stopping"}} end}
    else
      error -> {:ok, fn _, _ -> {:error, %{error_description: "#{inspect error}"}} end}
    end
  end
  def terminate_request_handler(_blk, _), do: {:ok, :continue}

  defp terminate_existing({:error, _msg1}, {:error, _msg2}, blk),
   do: {:error, "Neither Task nor Subppls where found for block with id: #{blk.block_id}"}

  defp terminate_existing(found_task, found_subppls, blk) do
    with :ok   <- terminate_task(found_task, blk),
    do: terminate_all_subppls(found_subppls, blk)
  end

  defp terminate_task({:ok, task}, blk) do
    params = [task, blk.terminate_request, blk.terminate_request_desc]
    case apply(TasksQueries, :terminate, params) do
      {:ok, _subpple} -> :ok
      error -> error
    end
  end
  defp terminate_task(_found_task, _blk), do: :ok

  defp terminate_all_subppls({:ok, blk_subppls}, blk) do
    blk_subppls
    |> Enum.reduce(:ok, fn subppl, prev_action -> terminate_subppl(subppl, blk, prev_action) end)
  end
  defp terminate_all_subppls(_found_subppls, _blk), do: :ok

  defp terminate_subppl(subppl, blk, :ok) do
    params = [subppl, blk.terminate_request, blk.terminate_request_desc]
    case apply(BlockSubpplsQueries, :terminate, params) do
      {:ok, _subpple} -> :ok
      error -> error
    end
  end
  defp terminate_subppl(_subppl, _blk, error), do: error

  def scheduling_handler(blk) do
    blk.block_id
    |> TasksQueries.get_by_id()
    |> determin_block_state()
  end

  defp determin_block_state({:ok, task}) do
    {state, result, result_reason} = determin_status(task)
    determin_state_transition({state, result, result_reason})
  end

  defp determin_block_state({:error, msg}) do
    error_desc = "Error: #{inspect msg}"
    {:ok, fn _, _ -> {:error, %{error_description: error_desc}} end}
  end

  # Merging of task's and subppl's states in full v3 will be implemented here
  defp determin_status(task), do: {task.state, task.result, task.result_reason}

  defp determin_state_transition({"done", result, result_reason}) when is_nil(result_reason),
    do: {:ok, fn _, _ -> {:ok, %{state: "done", result: result}} end}

  defp determin_state_transition({"done", result, result_reason}),
    do: {:ok, fn _, _ -> {:ok, %{state: "done", result: result, result_reason: result_reason}} end}

  defp determin_state_transition({_, _, _}),
    do: {:ok, fn _, _ -> {:ok, %{state: "running"}} end}

  defp determin_state_transition(error) do
    error_desc = "Error: #{inspect error}"
    {:ok, fn _, _ -> {:error, %{error_description: error_desc}} end}
  end


  def epilogue_handler({:ok, data = %{user_exit_function: %{state: "done"}}}) do
    Common.notify_ppl_block_when_done(data)
    Common.send_metrics(data, __MODULE__)
    data |> Map.get(:user_exit_function) |> Common.send_state_watch_metric()
  end
  def epilogue_handler({:ok, data = %{user_exit_function: %{state: "stopping"}}}) do
    import Ecto.Query

    block_id = data |> Map.get(:exit_transition, %{}) |> Map.get(:block_id)

    fn query -> query |> where(block_id: ^block_id) end
    |> TaskRunningState.execute_now_with_predicate()
  end
  def epilogue_handler(_exit_state), do: :nothing
end
