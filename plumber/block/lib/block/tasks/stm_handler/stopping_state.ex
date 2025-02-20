defmodule Block.Tasks.STMHandler.StoppingState do
  @moduledoc """
  Handles stopping tasks
  """

  use Looper.STM,
    id: __MODULE__,
    period_ms: Util.Config.get_sleeping_period(:block, :task_stopping_sp),
    repo: Block.EctoRepo,
    schema: Block.Tasks.Model.Tasks,
    observed_state: "stopping",
    allowed_states: ~w(stopping done),
    cooling_time_sec: Util.Config.get_cooling_time(:block, :task_stopping_ct),
    columns_to_log: [:state, :recovery_count, :block_id]


  alias Block.TaskApiClient.GrpcClient, as: TaskApiClient
  alias Block.Tasks.STMHandler.Common
  alias Block.Tasks.Model.Tasks

  @handler_timeout 4321

  def initial_query(), do: Tasks

  def terminate_request_handler(_pple, _), do: {:ok, :continue}

  def scheduling_handler(task) do
    task
    |> get_description()
    |> handle_description(task)
  end

  defp get_description(task) do
    Wormhole.capture(
      TaskApiClient, :describe, [task.task_id, Common.task_api_url()],
      timeout_ms: @handler_timeout, stacktrace: true)
  end

  defp handle_description({:ok, {:ok, description}}, task) do
    with {:ok, task_desc}  <- Map.fetch(description, :task),
         {:ok, state}      <- Map.fetch(task_desc, :state),
         {:ok, state}      <- decode_status(state)
    do determin_state_transition(state, description, task)
    else
      e  -> handle_description({:error, inspect(e)}, task)
    end
  end

  defp handle_description({:error, msg}, _task) do
    desc = %{error: msg}
    {:ok, fn _, _ -> {:error, %{description: desc}} end}
  end

  defp determin_state_transition("done", desc, task) do
    reason = determin_reason(task)
    {:ok, fn _, _ -> {:ok, %{state: "done", description: desc, result: "stopped", result_reason: reason}} end}
  end

  # If it is not "done" we treat it as "stopping"
  defp determin_state_transition(state, _desc, _task) when is_binary(state) ,
    do: {:ok, fn _, _ -> {:ok, %{state: "stopping"}} end}

  defp decode_status(:FINISHED), do: {:ok, "done"}
  defp decode_status(status) do
    {:ok, status |> Atom.to_string() |> String.downcase()}
  end

  defp determin_reason(%{terminate_request_desc: "API call"}), do: "user"
  defp determin_reason(%{terminate_request_desc: "strategy"}), do: "strategy"
  defp determin_reason(_), do: "internal"


  def epilogue_handler({:ok, data = %{user_exit_function: %{state: "done"}}}) do
    Common.notify_block_when_done(data)
    Common.send_metrics(data, __MODULE__)
    data |> Map.get(:user_exit_function) |> Common.send_state_watch_metric()
  end
  def epilogue_handler(_exit_state), do: :nothing
end
