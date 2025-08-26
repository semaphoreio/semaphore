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
        # Some GRPC errors are expected and we don't need to do anything with them(validation, not found, etc).
        e in GRPC.RPCError ->
          Logger.error(
            "Service #{name} - request: #{inspect(request)} - Exited with a failure: #{inspect(e)}"
          )

          error_category = categorize_grpc_error(e.status)
          Watchman.increment({name, [error_category]})
          reraise e, __STACKTRACE__

        e ->
          Logger.error(
            "Service #{name} - request: #{inspect(request)} - Exited with an error: #{inspect(e)}"
          )

          Watchman.increment({name, ["ERROR"]})
          reraise e, __STACKTRACE__
      end
    end)
  end

  defp categorize_grpc_error(status) do
    case status do
      # Client errors (expected)
      status when status in [3, :invalid_argument] -> "CLIENT_ERROR"
      status when status in [5, :not_found] -> "CLIENT_ERROR"
      status when status in [6, :already_exists] -> "CLIENT_ERROR"
      status when status in [7, :permission_denied] -> "CLIENT_ERROR"
      status when status in [8, :resource_exhausted] -> "CLIENT_ERROR"
      status when status in [9, :failed_precondition] -> "CLIENT_ERROR"
      status when status in [11, :out_of_range] -> "CLIENT_ERROR"
      # Server errors (unexpected)
      _ -> "SERVER_ERROR"
    end
  end
end
