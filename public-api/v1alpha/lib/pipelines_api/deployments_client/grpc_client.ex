defmodule PipelinesAPI.DeploymentTargetsClient.GrpcClient do
  @moduledoc """
  Module is used for making gRPC calls to Gofer/DeploymentTargets service.
  """

  alias InternalApi.Gofer.DeploymentTargets.DeploymentTargets
  alias PipelinesAPI.Util.{Log, Metrics, ToTuple}

  require Logger

  defp url(), do: System.get_env("GOFER_GRPC_URL")
  defp opts(), do: [{:timeout, Application.get_env(:pipelines_api, :grpc_timeout)}]

  # List

  def list({:ok, list_request}) do
    result =
      Wormhole.capture(__MODULE__, :list_, [list_request], stacktrace: true, skip_log: true)

    case result do
      {:ok, result} -> result
      {:error, reason} -> Log.internal_error(reason, "list")
    end
  end

  def list(error), do: error

  def list_(list_request) do
    {:ok, channel} = GRPC.Stub.connect(url())

    Metrics.benchmark("PipelinesAPI.deployments_client.grpc_client", ["list"], fn ->
      channel
      |> DeploymentTargets.Stub.list(list_request, opts())
      |> process_response("list")
    end)
  end

  # Create

  def create({:ok, create_request}) do
    result =
      Wormhole.capture(__MODULE__, :create_, [create_request], stacktrace: true, skip_log: true)

    case result do
      {:ok, result} -> result
      {:error, reason} -> Log.internal_error(reason, "create")
    end
  end

  def create(error), do: error

  def create_(create_request) do
    {:ok, channel} = GRPC.Stub.connect(url())

    Metrics.benchmark("PipelinesAPI.deployments_client.grpc_client", ["create"], fn ->
      channel
      |> DeploymentTargets.Stub.create(create_request, opts())
      |> process_response("create")
    end)
  end

  def update({:ok, update_request}) do
    result =
      Wormhole.capture(__MODULE__, :update_, [update_request], stacktrace: true, skip_log: true)

    case result do
      {:ok, result} -> result
      {:error, reason} -> Log.internal_error(reason, "update")
    end
  end

  def update(error), do: error

  def update_(update_request) do
    {:ok, channel} = GRPC.Stub.connect(url())

    Metrics.benchmark("PipelinesAPI.deployments_client.grpc_client", ["update"], fn ->
      channel
      |> DeploymentTargets.Stub.update(update_request, opts())
      |> process_response("update")
    end)
  end

  def delete({:ok, delete_request}) do
    result =
      Wormhole.capture(__MODULE__, :delete_, [delete_request], stacktrace: true, skip_log: true)

    case result do
      {:ok, result} -> result
      {:error, reason} -> Log.internal_error(reason, "delete")
    end
  end

  def delete(error), do: error

  def delete_(delete_request) do
    {:ok, channel} = GRPC.Stub.connect(url())

    Metrics.benchmark("PipelinesAPI.deployments_client.grpc_client", ["delete"], fn ->
      channel
      |> DeploymentTargets.Stub.delete(delete_request, opts())
      |> process_response("delete")
    end)
  end

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

    Metrics.benchmark("PipelinesAPI.deployments_client.grpc_client", ["describe"], fn ->
      channel
      |> DeploymentTargets.Stub.describe(describe_request, opts())
      |> process_response("describe")
    end)
  end

  def history({:ok, history_request}) do
    result =
      Wormhole.capture(__MODULE__, :history_, [history_request], stacktrace: true, skip_log: true)

    case result do
      {:ok, result} -> result
      {:error, reason} -> Log.internal_error(reason, "history")
    end
  end

  def history(error), do: error

  def history_(history_request) do
    {:ok, channel} = GRPC.Stub.connect(url())

    Metrics.benchmark("PipelinesAPI.deployments_client.grpc_client", ["history"], fn ->
      channel
      |> DeploymentTargets.Stub.history(history_request, opts())
      |> process_response("history")
    end)
  end

  def cordon({:ok, cordon_request}) do
    result =
      Wormhole.capture(__MODULE__, :cordon_, [cordon_request], stacktrace: true, skip_log: true)

    case result do
      {:ok, result} -> result
      {:error, reason} -> Log.internal_error(reason, "cordon")
    end
  end

  def cordon(error), do: error

  def cordon_(cordon_request) do
    {:ok, channel} = GRPC.Stub.connect(url())

    Metrics.benchmark("PipelinesAPI.deployments_client.grpc_client", ["cordon"], fn ->
      channel
      |> DeploymentTargets.Stub.cordon(cordon_request, opts())
      |> process_response("cordon")
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
        ToTuple.user_error(message)

      # NotFound
      status == 5 ->
        ToTuple.not_found_error(message)

      true ->
        Log.internal_error(message, action, "DeploymentTargets")
    end
  end

  defp process_response(error, action) do
    Logger.error("Error on #{action}: #{inspect(error)}")
    error |> Log.internal_error(action, "DeploymentTargets")
  end
end
