defmodule PipelinesAPI.LoghubClient do
  @moduledoc """
  Module is used for fetching logs for cloud jobs from loghub
  """

  require Logger
  alias PipelinesAPI.Util.{Metrics, ToTuple}
  alias InternalApi.Loghub.GetLogEventsRequest
  alias LogTee, as: LT

  defp url(), do: System.get_env("LOGHUB_API_URL")

  # gRPC deadline for loghub calls, kept below the 30s edge timeout so a slow
  # request gets DEADLINE_EXCEEDED (503) instead of an edge 504. Wormhole's
  # timeout is set a bit above it, so the deadline fires first.
  defp loghub_timeout, do: Application.get_env(:pipelines_api, :loghub_stream_timeout, 25_000)
  defp wormhole_timeout, do: loghub_timeout() + 2_000

  # When the calling process dies (the HTTP client went away), gun closes the
  # connection after closing_timeout (default 15s); until then loghub keeps
  # streaming a log nobody reads and holds a fetch slot for it.
  @connect_opts [adapter_opts: %{http2_opts: %{closing_timeout: 1_000}}]

  @unavailable GRPC.Status.unavailable()
  @unimplemented GRPC.Status.unimplemented()
  @unknown GRPC.Status.unknown()
  @data_loss GRPC.Status.data_loss()
  @deadline_exceeded GRPC.Status.deadline_exceeded()

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
        timeout_ms: wormhole_timeout(),
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
  # Fetches the whole log with the StreamLogEvents rpc and returns the same
  # result as get_log_events/1. stream_log_events/3 is the streaming version.
  #
  def stream_log_events(job_id) do
    case stream_log_events(job_id, [], fn events, batches -> {:cont, [events | batches]} end) do
      {:ok, batches} -> {:ok, batches |> Enum.reverse() |> Enum.concat()}
      {:error, error, _batches} -> {:error, error}
    end
  end

  @doc """
  Reads the log of a job with the StreamLogEvents rpc and calls
  `fun.(events, acc)` with each batch of events, oldest first, as loghub sends
  it. `fun` returns `{:cont, acc}` to read on, or `{:halt, acc}` to stop (the
  call is cancelled). Only one batch is held at a time.

  The stream is read in the calling process: the connection delivers the
  stream's messages to the process that opened it. The call is cancelled
  (the connection closed) when it ends for any reason, including the caller
  being killed, so loghub stops streaming a log nobody reads.

  Returns:

    - `{:ok, acc}` - the whole log was read
    - `{:halted, acc}` - `fun` stopped the call
    - `{:error, error, acc}` - `error` is what get_log_events/1 would return
      as `{:error, error}`, e.g. `{:not_found, message}`; `acc` holds what
      `fun` already got, since the call can fail after some batches

  Falls back to GetLogEvents (the whole log as one batch) when loghub doesn't
  implement the stream yet.
  """
  def stream_log_events(job_id, acc, fun) do
    Metrics.benchmark(__MODULE__, ["stream_log_events"], fn ->
      case form_get_log_events_request(job_id) do
        {:ok, request} -> grpc_stream_call(request, acc, fun)
        _error -> {:error, {:internal, "Internal error"}, acc}
      end
    end)
  end

  defp grpc_stream_call(request, acc, fun) do
    case stream_call(request, acc, fun) do
      # A loghub without StreamLogEvents rejects the call before sending any
      # response: UNIMPLEMENTED in general, but grpc-elixir 0.5 servers answer
      # an unknown method with UNKNOWN. Either way, use GetLogEvents instead.
      {:rejected, %GRPC.RPCError{status: status} = error}
      when status in [@unimplemented, @unknown] ->
        Logger.warning(
          "loghub rejected StreamLogEvents (status #{status}: #{error.message}), falling back to GetLogEvents"
        )

        Metrics.increment(__MODULE__, ["stream_log_events_fallback", "status_#{status}"])

        case get_log_events(request.job_id) do
          {:ok, events} -> continue(fun.(events, acc))
          {:error, error} -> {:error, error, acc}
        end

      {:rejected, error} ->
        error |> LT.error("loghub service responded with")
        {:error, error_tuple({:error, error}), acc}

      {:error, reason, acc} ->
        reason |> LT.error("loghub service responded with")
        {:error, error_tuple(reason), acc}

      # loghub's own answer, e.g. not found; already an error tuple.
      {:answered, error, acc} ->
        {:error, error, acc}

      result ->
        result
    end
  end

  defp continue({:cont, acc}), do: {:ok, acc}
  defp continue({:halt, acc}), do: {:halted, acc}

  defp error_tuple(reason) do
    {:error, error} = error_for(reason)
    error
  end

  #
  # The deadline is sent to loghub as grpc-timeout, and grpc-elixir servers
  # end the call with DEADLINE_EXCEEDED when it passes (gun's own timeout only
  # bounds the wait for each message).
  #
  defp stream_call(request, acc, fun) do
    case GRPC.Stub.connect(url(), @connect_opts) do
      {:ok, channel} -> stream_call(channel, request, acc, fun)
      {:error, error} -> {:error, {:error, error}, acc}
    end
  end

  # Exceptions raised by fun are not caught: only the caller knows what it
  # already did with the batches.
  defp stream_call(channel, request, acc, fun) do
    case InternalApi.Loghub.Loghub.Stub.stream_log_events(channel, request,
           timeout: loghub_timeout()
         ) do
      {:ok, responses} -> read_stream(responses, acc, fun)
      # The call failed before loghub sent anything back.
      {:error, error} -> {:rejected, error}
    end
  after
    # Closes the connection right away, which also cancels a stream that is
    # still running (GRPC.Stub.disconnect/1 would let it run on for gun's
    # closing_timeout). If the caller is killed instead, gun closes the
    # connection closing_timeout (1s, see @connect_opts) after it goes down.
    :gun.close(channel.adapter_payload.conn_pid)
  end

  #
  # Calls fun with the events of each response. The first response carries
  # the status, and every response must have the same one: a status change
  # mid-stream (e.g. OK batches followed by BAD_PARAM) means the batches are
  # not a whole log. A successful stream has at least one response, so an
  # empty one is an error. Responses are pulled one at a time, so a read that
  # raises still reports what fun got.
  #
  defp read_stream(responses, acc, fun) do
    # Suspending right away sets the stream up without reading from it.
    {:suspended, nil, cont} =
      Enumerable.reduce(responses, {:suspend, nil}, fn response, _ -> {:suspend, response} end)

    read_next(cont, nil, acc, fun)
  end

  defp read_next(cont, first, acc, fun) do
    case pull(cont) do
      {:ok, {:ok, response}, cont} ->
        case handle_response(response, first, acc, fun) do
          {:cont, first, acc} ->
            read_next(cont, first, acc, fun)

          result ->
            cont.({:halt, nil})
            result
        end

      {:ok, {:error, error}, cont} ->
        cont.({:halt, nil})
        {:error, {:error, error}, acc}

      {:ok, _other, cont} ->
        read_next(cont, first, acc, fun)

      :done when first == nil ->
        {:error, {:error, :empty_stream}, acc}

      :done ->
        {:ok, acc}

      {:raised, e} ->
        {:error, {:error, e}, acc}
    end
  end

  defp pull(cont) do
    case cont.({:cont, nil}) do
      {:suspended, element, cont} -> {:ok, element, cont}
      {:done, _} -> :done
      {:halted, _} -> :done
    end
  rescue
    e -> {:raised, e}
  end

  # The first response decides: OK starts the log, anything else (e.g.
  # BAD_PARAM for a log that can't be found) is loghub's answer, sent as the
  # only response.
  defp handle_response(%{status: %{code: code}} = response, nil, acc, fun) do
    if code == ok_code() do
      call(fun, response.events, code, acc)
    else
      {:error, error} = process_get_log_events_response(response)
      {:answered, error, acc}
    end
  end

  defp handle_response(%{status: %{code: code}} = response, first, acc, fun)
       when code == first,
       do: call(fun, response.events, first, acc)

  defp handle_response(_response, _first, acc, _fun),
    do: {:error, {:error, :inconsistent_stream}, acc}

  defp call(fun, events, first, acc) do
    case fun.(events, acc) do
      {:cont, acc} -> {:cont, first, acc}
      {:halt, acc} -> {:halted, acc}
    end
  end

  defp ok_code, do: InternalApi.ResponseStatus.Code.value(:OK)

  # loghub is up but can't serve the log right now (archive unavailable or
  # too busy); the request can be retried.
  defp error_for({:error, %GRPC.RPCError{status: @unavailable}}),
    do: ToTuple.unavailable_error("Logs are temporarily unavailable, please retry")

  # loghub ended the stream without any response, which a successful stream
  # never does; most likely it went away mid-request. Retryable.
  defp error_for({:error, :empty_stream}),
    do: ToTuple.unavailable_error("Logs are temporarily unavailable, please retry")

  # loghub didn't finish within the deadline (e.g. busy, or a very slow
  # archive read); the request can be retried.
  defp error_for({:error, %GRPC.RPCError{status: @deadline_exceeded}}),
    do: ToTuple.unavailable_error("Logs are temporarily unavailable, please retry")

  # The stored log is corrupt. Retrying won't help, so this stays a 500.
  defp error_for({:error, %GRPC.RPCError{status: @data_loss}}),
    do: ToTuple.internal_error("Internal error")

  defp error_for(_reason), do: ToTuple.internal_error("Internal error")

  def do_get_log_events(request) do
    {:ok, channel} = url() |> GRPC.Stub.connect(@connect_opts)

    try do
      InternalApi.Loghub.Loghub.Stub.get_log_events(channel, request, timeout: loghub_timeout())
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
