defmodule PipelinesAPI.LoghubClient do
  @moduledoc """
  Module is used for fetching logs for cloud jobs from loghub
  """

  require Logger
  alias PipelinesAPI.Util.{Metrics, ToTuple}
  alias InternalApi.Loghub.GetLogEventsRequest
  alias LogTee, as: LT

  defp url(), do: System.get_env("LOGHUB_API_URL")

  @wormhole_timeout Application.compile_env(:pipelines_api, :grpc_timeout, [])

  @unavailable GRPC.Status.unavailable()
  @unimplemented GRPC.Status.unimplemented()
  @unknown GRPC.Status.unknown()
  @data_loss GRPC.Status.data_loss()

  def get_log_events(job_id) do
    Metrics.benchmark(__MODULE__, ["get_log_events"], fn ->
      form_get_log_events_request(job_id)
      |> grpc_call()
    end)
  end

  def form_get_log_events_request(job_id) do
    GetLogEventsRequest.new(job_id: job_id)
    |> ToTuple.ok()
  catch
    error -> error
  end

  defp grpc_call({:ok, request}) do
    result =
      Wormhole.capture(__MODULE__, :do_get_log_events, [request],
        stacktrace: true,
        skip_log: true,
        timeout_ms: @wormhole_timeout,
        ok_tuple: true
      )

    case result do
      {:ok, result} ->
        process_get_log_events_response(result)

      {:error, reason} ->
        reason |> LT.error("loghub service responded with")
        error_for(reason)
    end
  end

  defp grpc_call(error), do: error

  #
  # Fetches the events with the StreamLogEvents rpc, so that loghub sends the
  # log in batches instead of one message holding all of it. Returns the same
  # result as get_log_events/1. Falls back to GetLogEvents when loghub doesn't
  # implement the stream yet.
  #
  def stream_log_events(job_id) do
    Metrics.benchmark(__MODULE__, ["stream_log_events"], fn ->
      form_get_log_events_request(job_id)
      |> grpc_stream_call()
    end)
  end

  defp grpc_stream_call({:ok, request}) do
    result =
      Wormhole.capture(__MODULE__, :do_stream_log_events, [request],
        stacktrace: true,
        skip_log: true,
        timeout_ms: @wormhole_timeout,
        ok_tuple: true
      )

    case result do
      {:ok, response} ->
        process_get_log_events_response(response)

      # Wormhole wraps an {:error, _} returned by the function in another one.
      #
      # A loghub without StreamLogEvents rejects the call before sending any
      # response: UNIMPLEMENTED in general, but grpc-elixir 0.5 servers answer
      # an unknown method with UNKNOWN. Either way, use GetLogEvents instead.
      {:error, {:error, {:rejected, %GRPC.RPCError{status: status} = error}}}
      when status in [@unimplemented, @unknown] ->
        Logger.warning(
          "loghub rejected StreamLogEvents (status #{status}: #{error.message}), falling back to GetLogEvents"
        )

        Metrics.increment(__MODULE__, ["stream_log_events_fallback", "status_#{status}"])
        get_log_events(request.job_id)

      {:error, {:error, {:rejected, error}}} ->
        error |> LT.error("loghub service responded with")
        error_for({:error, error})

      {:error, reason} ->
        reason |> LT.error("loghub service responded with")
        error_for(reason)
    end
  end

  defp grpc_stream_call(error), do: error

  #
  # Connects, reads the whole stream and disconnects, all in this process:
  # the connection delivers the stream's messages to the process that opened
  # it.
  #
  def do_stream_log_events(request) do
    {:ok, channel} = url() |> GRPC.Stub.connect()

    try do
      case InternalApi.Loghub.Loghub.Stub.stream_log_events(channel, request,
             timeout: @wormhole_timeout
           ) do
        {:ok, responses} -> collect_stream(responses)
        # The call failed before loghub sent anything back.
        {:error, error} -> {:error, {:rejected, error}}
      end
    after
      GRPC.Stub.disconnect(channel)
    end
  end

  #
  # Joins the batches into one response. The first response carries the
  # status. An error anywhere in the stream fails the whole call: the events
  # received before it are incomplete. A successful stream has at least one
  # response, so an empty one is an error too.
  #
  def collect_stream(responses) do
    result =
      Enum.reduce_while(responses, nil, fn
        {:ok, response}, nil -> {:cont, {response, [response.events]}}
        {:ok, response}, {first, batches} -> {:cont, {first, [response.events | batches]}}
        {:error, error}, _ -> {:halt, {:error, error}}
      end)

    case result do
      {:error, error} ->
        {:error, error}

      nil ->
        {:error, :empty_stream}

      {first, batches} ->
        {:ok, %{first | events: batches |> Enum.reverse() |> Enum.concat()}}
    end
  end

  # loghub is up but can't serve the log right now (archive unavailable or
  # too busy); the request can be retried.
  defp error_for({:error, %GRPC.RPCError{status: @unavailable}}),
    do: ToTuple.unavailable_error("Logs are temporarily unavailable, please retry")

  # loghub ended the stream without any response, which a successful stream
  # never does; most likely it went away mid-request. Retryable.
  defp error_for({:error, :empty_stream}),
    do: ToTuple.unavailable_error("Logs are temporarily unavailable, please retry")

  # The stored log is corrupt. Retrying won't help, so this stays a 500.
  defp error_for({:error, %GRPC.RPCError{status: @data_loss}}),
    do: ToTuple.internal_error("Internal error")

  defp error_for(_reason), do: ToTuple.internal_error("Internal error")

  def do_get_log_events(request) do
    {:ok, channel} = url() |> GRPC.Stub.connect()

    try do
      InternalApi.Loghub.Loghub.Stub.get_log_events(channel, request, timeout: @wormhole_timeout)
    after
      GRPC.Stub.disconnect(channel)
    end
  end

  def process_get_log_events_response(response) do
    ok_code = InternalApi.ResponseStatus.Code.value(:OK)
    bad_param_code = InternalApi.ResponseStatus.Code.value(:BAD_PARAM)

    case response.status.code do
      ^ok_code ->
        {:ok, response.events}

      # Loghub returns BAD_PARAM when the job or its logs cannot be found,
      # e.g. when the job never started. This is not an internal error, so we
      # surface it as a 404 with loghub's message instead of a generic 500.
      ^bad_param_code ->
        ToTuple.not_found_error(logs_not_found_message(response.status))

      _ ->
        Logger.error("Error getting log events: #{inspect(response.status)}")
        ToTuple.internal_error("Internal error")
    end
  end

  defp logs_not_found_message(%{message: message}) when is_binary(message) and message != "",
    do: message

  defp logs_not_found_message(_status), do: "Logs not found"
end
