defmodule TaskApiReferent.Actions do
  @moduledoc """
  Module provides actions on task entity which are accesble through API.
  """

  alias TaskApiReferent.Runner
  alias TaskApiReferent.Validation
  alias TaskApiReferent.Service
  alias LogTee, as: LT

  def describe_many(task_ids) do
    Enum.reduce(task_ids, {:ok, []}, fn task_id, {:ok, acc} ->
      case Service.Task.get_description(task_id) do
        {:ok, task} -> {:ok, acc ++ [task]}
        {:error, msg = "'task_id' parameter" <> _rest} ->
          raise GRPC.RPCError, status: GRPC.Status.not_found, message: msg
      end
    end)
  end

  def terminate(task) do
    task.jobs
    |> Enum.map(fn(id) -> Service.Job.set_property(id, :stopped, true) end)
    |> check_for_errors()
  end

  defp check_for_errors(results) do
    case Enum.find_index(results, &(is_tuple(&1) && elem(&1, 0) == :error)) do
      nil -> {:ok, ""}
      index -> {:error, elem(Enum.at(results, index), 1)}
    end
  end

  def schedule(params) do
    with {:ok, params} <- Validation.Task.validate(params),
         false         <- already_scheduled?(params),
         task_id       <- UUID.uuid4(),
         {:ok, _}      <- log_info(params)
    do
      Runner.Task.start(params, task_id)
    else
      {:alredy_scheduled, id} -> Service.Task.get_description(id)
      e -> e
    end
  end

  defp already_scheduled?(params) do
    case Service.Task.get_task_id(params.request_token) do
      {:ok, id} -> {:alredy_scheduled, id}
      _error -> false
    end
  end

  defp log_info(params) do
    with jobs_logs  <- maps_to_string(params.jobs),
         info       <- "request_token: '#{params.request_token}', " <>
                       "ppl_id: '#{params.ppl_id}', wf_id: '#{params.wf_id}', " <>
                       "jobs: '#{jobs_logs}'"
    do
      LT.info(info, "Schedule Request")
      {:ok, "Information about schedule request has been logged."}
    end
  end

  # Transform List of Maps to the Strings we can display in Log
  defp maps_to_string(maps) do
    output =
    Enum.reduce(maps, "[", fn(map, acc) ->
      acc <> to_str(map)
    end)

    if String.length(output) > 1 do
      String.slice(output, 0..-3) <> "]"
    else
      output <> "]"
    end
  end

  defp to_str(nil), do: "nil"

  defp to_str(map) when is_map(map) and map == %{}, do: "%{}"
  defp to_str(map) when is_map(map) do
    map
    |> Enum.reduce("%{", fn({key, value}, acc) ->
        acc <> "#{key}: #{to_str(value)}, "
    end)
    |> String.slice(0..-3)
    |> Kernel.<>("}, ")
  end

  defp to_str(list) when is_list(list) and length(list) > 0 do
    list
    |> Enum.reduce("[", fn(elem, acc) ->
      acc <> "'#{to_str(elem)}', "
    end)
    |> String.slice(0..-3)
    |> Kernel.<>("]")
  end
  defp to_str(list) when is_list(list), do: "[]"


  defp to_str(val) when is_binary(val), do: val
  defp to_str(val), do: "#{inspect val}"
end
