defmodule PipelinesAPI.JobsClient do
  @moduledoc """
  Module is used for handling jobs via gRPC calls to Zevbra service.
  """

  alias PipelinesAPI.Util.{Metrics, ToTuple}
  alias InternalApi.ServerFarm.Job.{JobService, DescribeRequest}
  alias InternalApi.ServerFarm.Job.Job.{State, Result}
  alias Google.Protobuf.Timestamp
  alias Util.Proto
  alias LogTee, as: LT

  defp url(), do: System.get_env("JOBS_API_URL")

  @wormhole_timeout Application.compile_env(:pipelines_api, :grpc_timeout, [])

  def describe(params) do
    Metrics.benchmark(__MODULE__, ["describe"], fn ->
      params
      |> form_describe_request()
      |> grpc_call()
    end)
  end

  def form_describe_request(params) when is_map(params) do
    %{
      job_id: params |> Map.get("job_id", "")
    }
    |> DescribeRequest.new()
    |> ToTuple.ok()
  catch
    error -> error
  end

  def form_describe_request(_), do: ToTuple.internal_error("Internal error")

  defp grpc_call({:ok, request}) do
    result =
      Wormhole.capture(__MODULE__, :do_describe_call, [request],
        stacktrace: true,
        skip_log: true,
        timeout_ms: @wormhole_timeout,
        ok_tuple: true
      )

    case result do
      {:ok, result} ->
        process_describe_response(result)

      {:error, reason} ->
        reason |> LT.error("Zebra service responded to 'describe' with:")
        ToTuple.internal_error("Internal error")
    end
  end

  defp grpc_call(error), do: error

  def do_describe_call(request) do
    {:ok, channel} = url() |> GRPC.Stub.connect()

    JobService.Stub.describe(channel, request, timeout: @wormhole_timeout)
  end

  def process_describe_response(describe_response) do
    with tf_map <- %{
           Timestamp => {__MODULE__, :timestamp_to_datetime_string},
           State => {__MODULE__, :enum_to_string},
           Result => {__MODULE__, :enum_to_string}
         },
         {:ok, response} <- Proto.to_map(describe_response, transformations: tf_map),
         :OK <- response.status.code do
      {:ok, response.job}
    else
      :BAD_PARAM ->
        describe_response.status |> Map.get(:message) |> ToTuple.not_found_error()

      _ ->
        log_invalid_response(describe_response, "describe")
    end
  end

  # Utility

  def timestamp_to_datetime_string(_name, %{nanos: 0, seconds: 0}), do: ""

  def timestamp_to_datetime_string(_name, %{nanos: nanos, seconds: seconds}) do
    ts_in_microseconds = seconds * 1_000_000 + Integer.floor_div(nanos, 1_000)
    {:ok, ts_date_time} = DateTime.from_unix(ts_in_microseconds, :microsecond)
    DateTime.to_string(ts_date_time)
  end

  def enum_to_string(_name, value) when is_binary(value) do
    value |> Atom.to_string() |> String.downcase()
  end

  def enum_to_string(name, value) when is_integer(value) do
    atom =
      case name do
        :state -> State.key(value)
        :result -> Result.key(value)
      end

    atom |> Atom.to_string() |> String.downcase()
  end

  defp log_invalid_response(response, rpc_method) do
    response
    |> LT.error("Zebra service responded to #{rpc_method} with :ok and invalid data:")

    ToTuple.internal_error("Internal error")
  end
end
