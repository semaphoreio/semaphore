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
    |> handle_description(task)
  end

  defp get_description(task) do
    Wormhole.capture(
      TaskApiClient, :describe, [task.task_id, Common.task_api_url()],
      timeout_ms: @handler_timeout, stacktrace: true)
  end

  defp handle_description({:ok, {:ok, description}}, task) do
    with {:ok, task_desc}        <- Map.fetch(description, :task),
         {:ok, state}            <- Map.fetch(task_desc, :state),
         {:ok, result}           <- Map.fetch(task_desc, :result),
         {:ok, [state, result]}  <- decode_status([state, result])
    do determin_state_transition({state, result}, description, task)
    else
      e  -> handle_description_error(description, inspect(e))
    end
  end

  defp handle_description(description, _task) do
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

  defp determin_state_transition({"done", "failed"}, desc, _task),
    do: {:ok, fn _, _ -> {:ok, %{state: "done", description: desc, result: "failed", result_reason: "test"}} end}

  defp determin_state_transition({"done", result}, desc, _task),
    do: {:ok, fn _, _ -> {:ok, %{state: "done", description: desc, result: result}} end}

  defp determin_state_transition({"deleted", _result}, desc, _task),
    do: {:ok, fn _, _ -> {:ok, %{state: "done", description: desc, result: "stopped", result_reason: "deleted"}} end}

  # If it is not "done" or "deleted" we treat it as "running".
  # The description is only written when it differs from the stored one: for a
  # task with many jobs it is a large jsonb value, and rewriting it on every poll
  # produces a new TOAST copy and WAL even when nothing changed.
  defp determin_state_transition({state, _}, desc, task) when is_binary(state) do
    if same_description?(desc, Map.get(task, :description)) do
      {:ok, fn _, _ -> {:ok, %{state: "running"}} end}
    else
      {:ok, fn _, _ -> {:ok, %{state: "running", description: desc}} end}
    end
  end

  # The stored value is what Postgrex wrote with Jason, read back with string
  # keys. The new description is compared to it as Jason would encode it (atom
  # keys and values as strings, DateTime as ISO 8601), walking both terms
  # instead of encoding the whole description. Anything else is treated as
  # changed, which only costs a write.
  @doc false
  def same_description?(_desc, nil), do: false
  def same_description?(desc, stored), do: same_json?(desc, stored)

  defp same_json?(%DateTime{} = value, stored) when is_binary(stored),
    do: DateTime.to_iso8601(value) == stored

  defp same_json?(value, _stored) when is_struct(value), do: false

  defp same_json?(value, stored) when is_map(value) and is_map(stored) do
    map_size(value) == map_size(stored) and
      Enum.all?(value, fn {key, item} ->
        case Map.fetch(stored, json_key(key)) do
          {:ok, stored_item} -> same_json?(item, stored_item)
          :error -> false
        end
      end)
  end

  defp same_json?([], []), do: true
  defp same_json?([item | rest], [stored_item | stored_rest]),
    do: same_json?(item, stored_item) and same_json?(rest, stored_rest)

  defp same_json?(value, stored) when value in [nil, true, false], do: value === stored
  defp same_json?(value, stored) when is_atom(value), do: Atom.to_string(value) === stored
  defp same_json?(value, stored), do: value === stored

  defp json_key(key) when is_atom(key), do: Atom.to_string(key)
  defp json_key(key), do: key

  def epilogue_handler({:ok, data = %{user_exit_function: %{state: "done"}}}) do
    Common.notify_block_when_done(data)
    Common.send_metrics(data, __MODULE__)
    data |> Map.get(:user_exit_function) |> Common.send_state_watch_metric()
  end
  def epilogue_handler(_exit_state), do: :nothing
end
