defmodule Ppl.TaskClient do
  @moduledoc """
  Task client for creating and managing tasks.
  """
  @handler_timeout 4321

  alias Block.TaskApiClient.GrpcClient, as: TaskApiClient

  def schedule(task_params) do
    Wormhole.capture(
      TaskApiClient,
      :schedule,
      task_params,
      timeout_ms: @handler_timeout,
      stacktrace: true
    )
  end

  def describe_details(task_id) do
    task_id
    |> get_description()
    |> case do
      {:ok, description} -> description
      error -> error
    end
  end

  def describe(task_id) do
    task_id
    |> get_description()
    |> handle_description()
  end

  def terminate(task_id) do
    with {:ok, response} <-
           Wormhole.capture(
             TaskApiClient,
             :terminate,
             [task_id, task_api_url()],
             timeout_ms: @handler_timeout,
             stacktrace: true
           ),
         do: response
  end

  def task_api_url(), do: System.get_env("INTERNAL_API_URL_TASK")

  defp get_description(task_id) do
    Wormhole.capture(
      TaskApiClient,
      :describe,
      [task_id, task_api_url()],
      timeout_ms: @handler_timeout,
      stacktrace: true
    )
  end

  defp handle_description({:ok, {:ok, description}}) do
    with {:ok, task_desc} <- Map.fetch(description, :task),
         {:ok, state} <- Map.fetch(task_desc, :state),
         {:ok, result} <- Map.fetch(task_desc, :result),
         {:ok, [state, result]} <- decode_status([state, result]) do
      {:ok, state, result}
    else
      e -> handle_description_error(description, inspect(e))
    end
  end

  defp handle_description(error = {:error, _e}), do: error
  defp handle_description(error), do: %{error: error}

  defp handle_description_error(description, msg) do
    %{error: %{task_api_response: description, processing_error: msg}}
  end

  defp decode_status([:FINISHED, result]), do: decode_status([:DONE, result])

  defp decode_status(status) do
    {:ok, Enum.map(status, &String.downcase(Atom.to_string(&1)))}
  end
end
