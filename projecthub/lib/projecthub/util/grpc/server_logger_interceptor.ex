# credo:disable-for-this-file Credo.Check.Design.DuplicatedCode
defmodule Projecthub.Util.GRPC.ServerLoggerInterceptor do
  require Logger
  @behaviour GRPC.ServerInterceptor

  def init(opts) do
    opts
  end

  def call(request, stream, next, _opts) do
    start = System.monotonic_time()
    action = to_string(elem(stream.rpc, 0))

    try do
      next.(request, stream)
      |> tap(fn
        {:ok, _stream, response} ->
          duration = stopwatch(start)
          maybe_log("✅ #{action} in #{format_duration(duration)}", is_long_request?(duration))
          Logger.debug("✅ #{action} #{inspect(response)}")
      end)
    rescue
      exception in GRPC.RPCError ->
        duration = stopwatch(start)

        Logger.error("❌ #{action} #{GRPC.Status.code_name(exception.status)} in #{format_duration(duration)}")
        Logger.error("❌ #{action} #{inspect(request)}")
        Logger.error("❌ #{action} #{exception.message}")

        reraise exception, __STACKTRACE__

      exception ->
        duration = stopwatch(start)

        Logger.error("🚨 #{action} #{duration}")
        Logger.error("🚨 #{action} #{inspect(exception)}")
        Logger.error("🚨 #{action} #{Exception.format_stacktrace(__STACKTRACE__)}")

        reraise exception, __STACKTRACE__
    end
  end

  # We don't want to log everything.
  defp maybe_log(message, true = _should_log?) do
    Logger.info(message)
  end

  defp maybe_log(message, _should_log?) do
    # Ignored actions still get logged in debug mode
    Logger.debug(message)
  end

  defp is_long_request?(duration) do
    div(duration, 1000) >= :timer.seconds(5)
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
