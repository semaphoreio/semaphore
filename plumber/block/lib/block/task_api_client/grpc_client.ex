defmodule Block.TaskApiClient.GrpcClient do
  @moduledoc """
  Calls Task API
  """

  alias LogTee, as: LT
  alias Util.{Metrics, Proto}
  alias Block.TaskApiClient.ScheduleRequestFormatter, as: ReqFormatter
  alias Google.Protobuf.Timestamp
  alias InternalApi.Task.{
    TaskService,
    DescribeRequest,
    TerminateRequest
  }

  require Logger

  @opts [{:timeout, 2_500_000}]


  @doc """
  Schedules task on Task API service.
  """
  def schedule(definition, params, server_url) do
    Metrics.benchmark("GrpcClient.schedule_entrypoint", fn ->
      with {:ok, request} <- ReqFormatter.to_proto_request(definition, params)
      do
        request
        |> schedule_task(server_url)
        |> response_to_map()
        |> extract_task()
      end
    end)
  end

  defp schedule_task(request, server_url) do
    {:ok, channel} = GRPC.Stub.connect(server_url)

    Logger.info("Scheduling with request: #{inspect(request)}")

    response = channel
    |> TaskService.Stub.schedule(request, @opts)

    Logger.info("Response: #{inspect(response)}")
    response
    |> log?("schedule")
  end

  defp extract_task({:ok, %{task: task}}), do: {:ok, task}
  defp extract_task(response), do: response

  @doc """
  Entrypoint for describe task call from ppl application.
  """
  def describe(task_id, server_url) do
    Metrics.benchmark("GrpcClient.describe_entrypoint", fn ->
      task_id
      |> describe_task(server_url)
      |> response_to_map()
    end)
  end

  defp describe_task(task_id, url) do
    request = DescribeRequest.new(task_id: task_id)
    {:ok, channel} = GRPC.Stub.connect(url)

    Logger.info("Describing with request: #{inspect(request)}")

    response =
    channel
    |> TaskService.Stub.describe(request, @opts)

    Logger.info("Response: #{inspect(response)}")
    response
    |> log?("describe")
  end

  @doc """
  Entrypoint for terminate task call from ppl application.
  """
  def terminate(task_id, server_url) do
    Metrics.benchmark("GrpcClient.terminate_entrypoint", fn ->
      task_id
      |> terminate_task(server_url)
      |> response_to_map()
    end)
  end

  defp terminate_task(task_id, url) do
    request = TerminateRequest.new(task_id: task_id)
    {:ok, channel} = GRPC.Stub.connect(url)

    Logger.info("Terminating with request: #{inspect(request)}")

    response = channel
    |> TaskService.Stub.terminate(request, @opts)

    Logger.info("Response: #{inspect(response)}")
    response
    |> log?("terminate")
  end

  # Utility

  defp response_to_map({:ok, response}) do
    tf_map = %{Timestamp => {__MODULE__, :timestamp_to_datetime}}
    response |> Proto.to_map(transformations: tf_map)
  end
  defp response_to_map(error = {:error, _msg}), do: error
  defp response_to_map(error), do: error

  def timestamp_to_datetime(_name, %{nanos: 0, seconds: 0}), do: :invalid_datetime
  def timestamp_to_datetime(_name, %{nanos: nanos, seconds: seconds}) do
    ts_in_microseconds = seconds * 1_000_000 + Integer.floor_div(nanos, 1_000)
    {:ok, ts_date_time} = DateTime.from_unix(ts_in_microseconds, :microsecond)
    ts_date_time
  end

  defp log?(server_response, rpc_method) do
    case log_bapi_grpc_response?() do
      "true" ->
        server_response
        |> LT.info("Task API server responded to #{rpc_method} request with: ")
      _ ->
        server_response
    end
  end

  defp log_bapi_grpc_response?(),
    do: System.get_env("LOG_TASK_API_GRPC_RESPONSE") || "false"
end
