defmodule PipelinesAPI.PreFlightChecksClient.GrpcClient do
  @moduledoc """
  Module is used for making gRPC calls to PreFlightChecksHub service.
  """

  alias InternalApi.PreFlightChecksHub.PreFlightChecksService
  alias PipelinesAPI.Util.{Log, Metrics, ToTuple}

  require Logger

  defp url(), do: Application.get_env(:pipelines_api, :pre_flight_checks_grpc_url)
  defp opts(), do: [{:timeout, Application.get_env(:pipelines_api, :grpc_timeout)}]

  # Describe

  def describe({:ok, describe_request}) do
    result =
      Wormhole.capture(__MODULE__, :describe_, [describe_request],
        stacktrace: true,
        skip_log: true
      )

    case result do
      {:ok, result} -> result
      {:error, reason} -> Log.internal_error(reason, "describe")
    end
  end

  def describe(error), do: error

  def describe_(describe_request) do
    {:ok, channel} = GRPC.Stub.connect(url())

    Metrics.benchmark("PipelinesAPI.pre_flight_checks_client.grpc_client", ["describe"], fn ->
      channel
      |> PreFlightChecksService.Stub.describe(describe_request, opts())
      |> process_response("describe")
    end)
  end

  # Apply

  def apply({:ok, apply_request}) do
    result =
      Wormhole.capture(__MODULE__, :apply_, [apply_request], stacktrace: true, skip_log: true)

    case result do
      {:ok, result} -> result
      {:error, reason} -> Log.internal_error(reason, "apply")
    end
  end

  def apply(error), do: error

  def apply_(apply_request) do
    {:ok, channel} = GRPC.Stub.connect(url())

    Metrics.benchmark("PipelinesAPI.pre_flight_checks_client.grpc_client", ["apply"], fn ->
      channel
      |> PreFlightChecksService.Stub.apply(apply_request, opts())
      |> process_response("apply")
    end)
  end

  # Destroy

  def destroy({:ok, destroy_request}) do
    result =
      Wormhole.capture(__MODULE__, :destroy_, [destroy_request], stacktrace: true, skip_log: true)

    case result do
      {:ok, result} -> result
      {:error, reason} -> Log.internal_error(reason, "destroy")
    end
  end

  def destroy(error), do: error

  def destroy_(destroy_request) do
    {:ok, channel} = GRPC.Stub.connect(url())

    Metrics.benchmark("PipelinesAPI.pre_flight_checks_client.grpc_client", ["destroy"], fn ->
      channel
      |> PreFlightChecksService.Stub.destroy(destroy_request, opts())
      |> process_response("destroy")
    end)
  end

  # Utility

  defp process_response({:ok, response}, _action), do: {:ok, response}

  defp process_response(
         {:error, _error = %GRPC.RPCError{message: message, status: status}},
         action
       ) do
    cond do
      # InvalidArgument, AlreadyExists, FailedPrecondition
      status in [3, 6, 9] ->
        ToTuple.unprocessable_error(message)

      # NotFound
      status == 5 ->
        ToTuple.not_found_error(message)

      true ->
        Log.internal_error(message, action, "PreFlightChecks")
    end
  end

  defp process_response(error, action) do
    Logger.error("Error on #{action}: #{inspect(error)}")
    error |> Log.internal_error(action, "PreFlightChecks")
  end
end
