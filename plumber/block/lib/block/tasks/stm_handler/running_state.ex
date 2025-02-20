defmodule Block.Tasks.STMHandler.RunningState do
  @moduledoc """
  Handles describing task's status
  """

  use Looper.STM,
    id: __MODULE__,
    period_ms: Util.Config.get_sleeping_period(:block, :task_running_sp),
    repo: Block.EctoRepo,
    schema: Block.Tasks.Model.Tasks,
    observed_state: "running",
    allowed_states: ~w(running stopping done),
    cooling_time_sec: Util.Config.get_cooling_time(:block, :task_running_ct),
    columns_to_log: [:state, :recovery_count, :block_id]

  alias Block.TaskApiClient.GrpcClient, as: TaskApiClient
  alias Block.Tasks.Model.Tasks
  alias Block.Tasks.STMHandler.Common

  @handler_timeout 4321

  def initial_query(), do: Tasks

  def terminate_request_handler(task, "stop") do
    case terminate_on_server(task) do
      {:ok, _response} ->
          {:ok, fn _, _ -> {:ok, %{state: "stopping"}} end}
      error ->
         {:ok, fn _, _ -> {:error, %{error_description: "#{inspect error}"}} end}
    end
  end
  def terminate_request_handler(_task, _), do: {:ok, :continue}

  defp terminate_on_server(task) do
    {:ok, response} = Wormhole.capture(TaskApiClient, :terminate,
                                       [task.task_id, Common.task_api_url()],
                                       timeout_ms: @handler_timeout, stacktrace: true)
    response
  end

  def scheduling_handler(task) do
    task
    |> get_description()
    |> handle_description()
  end

  defp get_description(task) do
    Wormhole.capture(
      TaskApiClient, :describe, [task.task_id, Common.task_api_url()],
      timeout_ms: @handler_timeout, stacktrace: true)
  end

  defp handle_description({:ok, {:ok, description}}) do
    with {:ok, task_desc}        <- Map.fetch(description, :task),
         {:ok, state}            <- Map.fetch(task_desc, :state),
         {:ok, result}           <- Map.fetch(task_desc, :result),
         {:ok, [state, result]}  <- decode_status([state, result])
    do determin_state_transition({state, result}, description)
    else
      e  -> handle_description_error(description, inspect(e))
    end
  end

  defp handle_description(description) do
    desc = %{error: description}
    {:ok, fn _ -> {:error, %{description: desc}} end}
  end

  defp handle_description_error(description, msg) do
    desc = %{error: %{task_api_response: description, processing_error: msg}}
    {:ok, fn _, _ -> {:error, %{description: desc}} end}
  end

  defp decode_status([:FINISHED, result]), do: decode_status([:DONE, result])
  defp decode_status(status) do
    {:ok, Enum.map(status, &(String.downcase(Atom.to_string(&1))))}
  end

  defp determin_state_transition({"done", "failed"}, desc),
    do: {:ok, fn _, _ -> {:ok, %{state: "done", description: desc, result: "failed", result_reason: "test"}} end}

  defp determin_state_transition({"done", result}, desc),
    do: {:ok, fn _, _ -> {:ok, %{state: "done", description: desc, result: result}} end}

  defp determin_state_transition({"deleted", _result}, desc),
    do: {:ok, fn _, _ -> {:ok, %{state: "done", description: desc, result: "stopped", result_reason: "deleted"}} end}

  # If it is not "done" or "deleted" we treat it as "running"
  defp determin_state_transition({state, _}, desc) when is_binary(state) ,
    do: {:ok, fn _, _ -> {:ok, %{state: "running", description: desc}} end}


  def epilogue_handler({:ok, data = %{user_exit_function: %{state: "done"}}}) do
    Common.notify_block_when_done(data)
    Common.send_metrics(data, __MODULE__)
    data |> Map.get(:user_exit_function) |> Common.send_state_watch_metric()
  end
  def epilogue_handler(_exit_state), do: :nothing
end
