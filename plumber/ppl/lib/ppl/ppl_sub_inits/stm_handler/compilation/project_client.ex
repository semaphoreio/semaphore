defmodule Ppl.PplSubInits.STMHandler.Compilation.ProjectClient do
  @moduledoc """
  Calls Project API
  """

  alias LogTee, as: LT
  alias Google.Protobuf.Timestamp
  alias Util.{Metrics, Proto, ToTuple}
  alias InternalApi.Projecthub.{
    ProjectService,
    DescribeRequest,
    RequestMeta,
  }

  defp url(), do: System.get_env("INTERNAL_API_URL_PROJECT")
  @opts [{:timeout, 2_500_000}]

  @doc """
  Entrypoint for describe project call from ppl application.
  """
  def describe(project_id) do
    result = Wormhole.capture(__MODULE__, :describe_project, [project_id],
      stacktrace: true,
      timeout: 3_000
    )

    case result do
      {:ok, result} -> result
      error -> error
    end
  end

  def describe_project(project_id) do
    Metrics.benchmark("Ppl.ProjectClient.describe", fn ->
      metadata = RequestMeta.new()
      request = DescribeRequest.new(metadata: metadata, id: project_id)
      {:ok, channel} = GRPC.Stub.connect(url())

      channel
      |> ProjectService.Stub.describe(request, @opts)
      |> response_to_map()
      |> process_status()
    end)
  end

  defp process_status({:ok, map}) do
    case map |> get_in([:metadata, :status, :code]) do
      :OK ->
        map |> Map.get(:project) |> ToTuple.ok()

      :NOT_FOUND ->
        map |> get_in([:metadata, :status, :message]) |> ToTuple.error()

      _ -> log_invalid_response(map)
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
