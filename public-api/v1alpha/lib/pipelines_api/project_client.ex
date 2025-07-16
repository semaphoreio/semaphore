defmodule PipelinesAPI.ProjectClient do
  @moduledoc """
  Calls Project API
  """

  alias LogTee, as: LT
  alias Util.Proto
  alias Google.Protobuf.Timestamp
  alias PipelinesAPI.Util.{Metrics, ToTuple}
  alias InternalApi.Projecthub.{ProjectService, DescribeRequest, RequestMeta, Project}

  defp url(), do: System.get_env("PROJECTHUB_API_GRPC_URL")

  @wormhole_timeout Application.compile_env(:pipelines_api, :grpc_timeout, [])

  def describe(project_id) do
    result =
      Wormhole.capture(__MODULE__, :describe_project, [project_id],
        stacktrace: true,
        timeout: @wormhole_timeout
      )

    ret = case result do
      {:ok, result} -> result
      error -> error
    end

    IO.puts("RET")
    IO.inspect(ret)
    ret
  end

  def describe_project(project_id) do
    Metrics.benchmark(__MODULE__, ["describe"], fn ->
      metadata = RequestMeta.new()
      request = DescribeRequest.new(metadata: metadata, id: project_id)
      IO.puts("DESCRIBE REQ")
      IO.inspect(request)
      {:ok, channel} = GRPC.Stub.connect(url())

      channel
      |> ProjectService.Stub.describe(request)
      |> response_to_map()
      |> process_status()
    end)
  end

  defp process_status({:ok, map}) do
    case map |> get_in([:metadata, :status, :code]) do
      :OK ->
        map |> Map.get(:project) |> ToTuple.ok()

      :NOT_FOUND ->
        map |> get_in([:metadata, :status, :message]) |> ToTuple.user_error()

      _ ->
        log_invalid_response(map)
    end
  end

  defp process_status(error = {:error, _msg}), do: error
  defp process_status(error), do: {:error, error}

  # Utility

  defp response_to_map({:ok, response}) do
    tf_map = %{Timestamp => {__MODULE__, :timestamp_to_datetime}}
    response |> Proto.to_map(transformations: tf_map)
  end

  defp response_to_map(error = {:error, _msg}), do: error
  defp response_to_map(error), do: {:error, error}

  def timestamp_to_datetime(_name, %{nanos: 0, seconds: 0}), do: nil

  def timestamp_to_datetime(_name, %{nanos: nanos, seconds: seconds}) do
    ts_in_microseconds = seconds * 1_000_000 + Integer.floor_div(nanos, 1_000)
    {:ok, ts_date_time} = DateTime.from_unix(ts_in_microseconds, :microsecond)
    ts_date_time
  end

  defp log_invalid_response(response) do
    response
    |> LT.error("ProjectAPI responded to Describe with :ok and invalid data:")
    |> ToTuple.error()
  end
end
