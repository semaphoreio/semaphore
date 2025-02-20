# credo:disable-for-this-file Credo.Check.Design.DuplicatedCode
defmodule RepositoryHub.Client.LoggerInterceptor do
  require Logger
  @behaviour GRPC.ClientInterceptor

  def init(opts) do
    opts
  end

  def call(stream, request, next, opts) do
    start = System.monotonic_time()
    action = to_string(elem(stream.rpc, 0))

    skip_logs_for = Keyword.get(opts, :skip_logs_for, [])
    should_log? = action not in skip_logs_for

    maybe_log("#{action} #{inspect(request)}", should_log?)

    next.(stream, request)
    |> tap(fn
      {:ok, response} ->
        duration = stopwatch(start)
        maybe_log("✅ #{action} in #{format_duration(duration)}", should_log? or long_request?(duration))
        Logger.debug("✅ #{action} #{inspect(response)}")

      {:error, error} ->
        duration = stopwatch(start)
        Logger.error("❌ #{action} failed in #{format_duration(duration)}")
        Logger.error("❌ #{action} #{inspect(request)}")
        Logger.error("❌ #{action} #{inspect(error)}")
    end)
  end

  defp long_request?(duration) do
    div(duration, 1000) >= :timer.seconds(5)
  end

  # We don't want to log everything.
  defp maybe_log(message, true = _should_log?) do
    Logger.info(message)
  end

  defp maybe_log(message, _should_log?) do
    # Ignored actions still get logged in debug mode
    Logger.debug(message)
  end

  defp long_request_mark(duration) do
    cond do
      duration >= :timer.seconds(15) ->
        " 🐢🐢🐢"

      duration >= :timer.seconds(10) ->
        " 🐢🐢"

      duration >= :timer.seconds(5) ->
        " 🐢"

      true ->
        ""
    end
  end

  defp stopwatch(start) do
    stop = System.monotonic_time()

    System.convert_time_unit(stop - start, :native, :microsecond)
  end

  defp format_duration(diff) when diff > 1000 do
    ms_diff = diff |> div(1000)
    [Integer.to_string(ms_diff), "ms", long_request_mark(ms_diff)]
  end

  defp format_duration(diff) do
    [Integer.to_string(diff), "µs"]
  end
end
