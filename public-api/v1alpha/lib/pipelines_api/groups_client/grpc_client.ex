defmodule PipelinesAPI.GroupsClient.GrpcClient do
  @moduledoc false
  alias InternalApi.Groups.Groups
  alias PipelinesAPI.Util.{Log, Metrics, ToTuple}

  require Logger

  defp url(), do: System.get_env("INTERNAL_API_URL_GROUPS")

  @wormhole_timeout Application.compile_env(:pipelines_api, :wormhole_timeout, [])
  @grpc_timeout Application.compile_env(:pipelines_api, :grpc_timeout, [])
  defp opts(), do: [{:timeout, @grpc_timeout}]

  def list({:ok, request}) do
    result =
      Wormhole.capture(__MODULE__, :list_, [request],
        stacktrace: true,
        skip_log: true,
        timeout_ms: @wormhole_timeout
      )

    case result do
      {:ok, result} -> result
      {:error, reason} -> Log.internal_error(reason, "list")
    end
  end

  def list(error), do: error

  def list_(request) do
    {:ok, channel} = GRPC.Stub.connect(url())

    Metrics.benchmark("PipelinesAPI.groups_client.grpc_client", ["list"], fn ->
      channel
      |> Groups.Stub.list_groups(request, opts())
      |> process_response("list")
    end)
  end

  def create({:ok, request}) do
    result =
      Wormhole.capture(__MODULE__, :create_, [request],
        stacktrace: true,
        skip_log: true,
        timeout_ms: @wormhole_timeout
      )

    case result do
      {:ok, result} -> result
      {:error, reason} -> Log.internal_error(reason, "create")
    end
  end

  def create(error), do: error

  def create_(request) do
    {:ok, channel} = GRPC.Stub.connect(url())

    Metrics.benchmark("PipelinesAPI.groups_client.grpc_client", ["create"], fn ->
      channel
      |> Groups.Stub.create_group(request, opts())
      |> process_response("create")
    end)
  end

  def modify({:ok, request}) do
    result =
      Wormhole.capture(__MODULE__, :modify_, [request],
        stacktrace: true,
        skip_log: true,
        timeout_ms: @wormhole_timeout
      )

    case result do
      {:ok, result} -> result
      {:error, reason} -> Log.internal_error(reason, "modify")
    end
  end

  def modify(error), do: error

  def modify_(request) do
    {:ok, channel} = GRPC.Stub.connect(url())

    Metrics.benchmark("PipelinesAPI.groups_client.grpc_client", ["modify"], fn ->
      channel
      |> Groups.Stub.modify_group(request, opts())
      |> process_response("modify")
    end)
  end

  def destroy({:ok, request}) do
    result =
      Wormhole.capture(__MODULE__, :destroy_, [request],
        stacktrace: true,
        skip_log: true,
        timeout_ms: @wormhole_timeout
      )

    case result do
      {:ok, result} -> result
      {:error, reason} -> Log.internal_error(reason, "destroy")
    end
  end

  def destroy(error), do: error

  def destroy_(request) do
    {:ok, channel} = GRPC.Stub.connect(url())

    Metrics.benchmark("PipelinesAPI.groups_client.grpc_client", ["destroy"], fn ->
      channel
      |> Groups.Stub.destroy_group(request, opts())
      |> process_response("destroy")
    end)
  end

  defp process_response({:ok, response}, _action), do: response |> Util.Proto.to_map()

  defp process_response({:error, %GRPC.RPCError{message: message, status: status}}, action) do
    cond do
      status in [3, 6, 9] -> ToTuple.user_error(message)
      status == 5 -> ToTuple.not_found_error(message)
      status == 7 -> ToTuple.forbidden_error(message)
      true -> Log.internal_error(message, action, "Groups")
    end
  end

  defp process_response({:error, error}, action) do
    Logger.error("Error on #{action}: #{inspect(error)}")
    error |> Log.internal_error(action, "Groups")
  end

  defp process_response(error, action) do
    Logger.error("Error on #{action}: #{inspect(error)}")
    error |> Log.internal_error(action, "Groups")
  end
end
