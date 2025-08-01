defmodule Guard.GrpcServers.Utils do
  @moduledoc """
  Common utilities for GRPC servers.
  """

  require Logger

  @doc """
  Observes and logs GRPC service calls with benchmarking and metrics.
  """
  def observe_and_log(name, request, f) do
    Watchman.benchmark(name, fn ->
      try do
        Logger.debug(fn -> "Service #{name} - request: #{inspect(request)} - Started" end)
        result = f.()
        Logger.debug(fn -> "Service #{name} - request: #{inspect(request)} - Finished" end)

        Watchman.increment({name, ["OK"]})
        result
      rescue
        e ->
          Logger.error(
            "Service #{name} - request: #{inspect(request)} - Exited with an error: #{inspect(e)}"
          )

          Watchman.increment({name, ["ERROR"]})
          reraise e, __STACKTRACE__
      end
    end)
  end
end
