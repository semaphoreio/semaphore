defmodule PipelinesAPI.SelfHostedHubClient.GrpcClient do
  @moduledoc """
  Module is used for making gRPC calls to Self-Hosted Hub service.
  """

  alias InternalApi.SelfHosted.SelfHostedAgents, as: SelfHostedHub
  alias PipelinesAPI.Util.{Log, Metrics, ToTuple}
  alias Util.Proto

  require Logger

  defp url(), do: System.get_env("SELF_HOSTED_HUB_URL")
  defp opts(), do: [{:timeout, Application.get_env(:pipelines_api, :grpc_timeout)}]

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

    Metrics.benchmark("PipelinesAPI.self_hosted_hub_client.grpc_client", ["create"], fn ->
      channel
      |> SelfHostedHub.Stub.create(create_request, opts())
      |> process_response("create")
    end)
  end

  # Update

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

    Metrics.benchmark("PipelinesAPI.self_hosted_hub_client.grpc_client", ["update"], fn ->
      channel
      |> SelfHostedHub.Stub.update(update_request, opts())
      |> process_response("update")
    end)
  end

  # Describe

  def describe({:ok, request}) do
    result = Wormhole.capture(__MODULE__, :describe_, [request], stacktrace: true, skip_log: true)

    case result do
      {:ok, result} -> result
      {:error, reason} -> Log.internal_error(reason, "describe")
    end
  end

  def describe(error), do: error

  def describe_(request) do
    {:ok, channel} = GRPC.Stub.connect(url())

    Metrics.benchmark("PipelinesAPI.self_hosted_hub_client.grpc_client", ["describe"], fn ->
      channel
      |> SelfHostedHub.Stub.describe(request, opts())
      |> process_response("describe")
    end)
  end

  # Describe

  def describe_agent({:ok, request}) do
    result =
      Wormhole.capture(__MODULE__, :describe_agent_, [request], stacktrace: true, skip_log: true)

    case result do
      {:ok, result} -> result
      {:error, reason} -> Log.internal_error(reason, "describe_agent")
    end
  end

  def describe_agent(error), do: error

  def describe_agent_(request) do
    {:ok, channel} = GRPC.Stub.connect(url())

    Metrics.benchmark("PipelinesAPI.self_hosted_hub_client.grpc_client", ["describe"], fn ->
      channel
      |> SelfHostedHub.Stub.describe_agent(request, opts())
      |> process_response("describe_agent")
    end)
  end

  # List

  def list({:ok, request}) do
    result = Wormhole.capture(__MODULE__, :list_, [request], stacktrace: true, skip_log: true)

    case result do
      {:ok, result} -> result
      {:error, reason} -> Log.internal_error(reason, "list")
    end
  end

  def list(error), do: error

  def list_(request) do
    {:ok, channel} = GRPC.Stub.connect(url())

    Metrics.benchmark("PipelinesAPI.self_hosted_hub_client.grpc_client", ["list"], fn ->
      channel
      |> SelfHostedHub.Stub.list(request, opts())
      |> process_response("list")
    end)
  end

  # List agents

  def list_agents({:ok, request}) do
    result =
      Wormhole.capture(__MODULE__, :list_agents_, [request], stacktrace: true, skip_log: true)

    case result do
      {:ok, result} -> result
      {:error, reason} -> Log.internal_error(reason, "list")
    end
  end

  def list_agents(error), do: error

  def list_agents_(request) do
    {:ok, channel} = GRPC.Stub.connect(url())

    Metrics.benchmark("PipelinesAPI.self_hosted_hub_client.grpc_client", ["list_agents"], fn ->
      channel
      |> SelfHostedHub.Stub.list_agents(request, opts())
      |> process_response("list_agents")
    end)
  end

  # Delete

  def delete({:ok, request}) do
    result = Wormhole.capture(__MODULE__, :delete_, [request], stacktrace: true, skip_log: true)

    case result do
      {:ok, result} -> result
      {:error, reason} -> Log.internal_error(reason, "delete")
    end
  end

  def delete(error), do: error

  def delete_(request) do
    {:ok, channel} = GRPC.Stub.connect(url())

    Metrics.benchmark("PipelinesAPI.self_hosted_hub_client.grpc_client", ["delete"], fn ->
      channel
      |> SelfHostedHub.Stub.delete_agent_type(request, opts())
      |> process_response("delete")
    end)
  end

  # Disable all

  def disable_all({:ok, request}) do
    result =
      Wormhole.capture(__MODULE__, :disable_all_, [request], stacktrace: true, skip_log: true)

    case result do
      {:ok, result} -> result
      {:error, reason} -> Log.internal_error(reason, "delete")
    end
  end

  def disable_all(error), do: error

  def disable_all_(request) do
    {:ok, channel} = GRPC.Stub.connect(url())

    Metrics.benchmark("PipelinesAPI.self_hosted_hub_client.grpc_client", ["disable_all"], fn ->
      channel
      |> SelfHostedHub.Stub.disable_all_agents(request, opts())
      |> process_response("disable_all")
    end)
  end

  # Utility

  defp process_response({:ok, response}, _action), do: response |> Proto.to_map()

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
        Log.internal_error(message, action, "SelfHostedHub")
    end
  end

  defp process_response({:error, error}, action) do
    Logger.error("Error on #{action}: #{inspect(error)}")
    error |> Log.internal_error(action, "SelfHostedHub")
  end

  defp process_response(error, action) do
    Logger.error("Error on #{action}: #{inspect(error)}")
    error |> Log.internal_error(action, "SelfHostedHub")
  end
end
