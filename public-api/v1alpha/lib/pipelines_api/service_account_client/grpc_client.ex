defmodule PipelinesAPI.ServiceAccountClient.GrpcClient do
  @moduledoc false
  alias InternalApi.ServiceAccount.ServiceAccountService, as: SAService
  alias PipelinesAPI.Util.{Log, Metrics, ToTuple}

  require Logger

  defp url(), do: System.get_env("INTERNAL_API_URL_SERVICE_ACCOUNT")

  @wormhole_timeout Application.compile_env(:pipelines_api, :wormhole_timeout, [])
  @grpc_timeout Application.compile_env(:pipelines_api, :grpc_timeout, [])
  defp opts(), do: [{:timeout, @grpc_timeout}]

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

    Metrics.benchmark("PipelinesAPI.service_account_client.grpc_client", ["create"], fn ->
      channel
      |> SAService.Stub.create(request, opts())
      |> process_response("create")
    end)
  end

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

    Metrics.benchmark("PipelinesAPI.service_account_client.grpc_client", ["list"], fn ->
      channel
      |> SAService.Stub.list(request, opts())
      |> process_response("list")
    end)
  end

  def describe({:ok, request}) do
    result =
      Wormhole.capture(__MODULE__, :describe_, [request],
        stacktrace: true,
        skip_log: true,
        timeout_ms: @wormhole_timeout
      )

    case result do
      {:ok, result} -> result
      {:error, reason} -> Log.internal_error(reason, "describe")
    end
  end

  def describe(error), do: error

  def describe_(request) do
    {:ok, channel} = GRPC.Stub.connect(url())

    Metrics.benchmark("PipelinesAPI.service_account_client.grpc_client", ["describe"], fn ->
      channel
      |> SAService.Stub.describe(request, opts())
      |> process_response("describe")
    end)
  end

  def update({:ok, request}) do
    result =
      Wormhole.capture(__MODULE__, :update_, [request],
        stacktrace: true,
        skip_log: true,
        timeout_ms: @wormhole_timeout
      )

    case result do
      {:ok, result} -> result
      {:error, reason} -> Log.internal_error(reason, "update")
    end
  end

  def update(error), do: error

  def update_(request) do
    {:ok, channel} = GRPC.Stub.connect(url())

    Metrics.benchmark("PipelinesAPI.service_account_client.grpc_client", ["update"], fn ->
      channel
      |> SAService.Stub.update(request, opts())
      |> process_response("update")
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

    Metrics.benchmark("PipelinesAPI.service_account_client.grpc_client", ["destroy"], fn ->
      channel
      |> SAService.Stub.destroy(request, opts())
      |> process_response("destroy")
    end)
  end

  def deactivate({:ok, request}) do
    result =
      Wormhole.capture(__MODULE__, :deactivate_, [request],
        stacktrace: true,
        skip_log: true,
        timeout_ms: @wormhole_timeout
      )

    case result do
      {:ok, result} -> result
      {:error, reason} -> Log.internal_error(reason, "deactivate")
    end
  end

  def deactivate(error), do: error

  def deactivate_(request) do
    {:ok, channel} = GRPC.Stub.connect(url())

    Metrics.benchmark("PipelinesAPI.service_account_client.grpc_client", ["deactivate"], fn ->
      channel
      |> SAService.Stub.deactivate(request, opts())
      |> process_response("deactivate")
    end)
  end

  def reactivate({:ok, request}) do
    result =
      Wormhole.capture(__MODULE__, :reactivate_, [request],
        stacktrace: true,
        skip_log: true,
        timeout_ms: @wormhole_timeout
      )

    case result do
      {:ok, result} -> result
      {:error, reason} -> Log.internal_error(reason, "reactivate")
    end
  end

  def reactivate(error), do: error

  def reactivate_(request) do
    {:ok, channel} = GRPC.Stub.connect(url())

    Metrics.benchmark("PipelinesAPI.service_account_client.grpc_client", ["reactivate"], fn ->
      channel
      |> SAService.Stub.reactivate(request, opts())
      |> process_response("reactivate")
    end)
  end

  def regenerate_token({:ok, request}) do
    result =
      Wormhole.capture(__MODULE__, :regenerate_token_, [request],
        stacktrace: true,
        skip_log: true
      )

    case result do
      {:ok, result} -> result
      {:error, reason} -> Log.internal_error(reason, "regenerate_token")
    end
  end

  def regenerate_token(error), do: error

  def regenerate_token_(request) do
    {:ok, channel} = GRPC.Stub.connect(url())

    Metrics.benchmark(
      "PipelinesAPI.service_account_client.grpc_client",
      ["regenerate_token"],
      fn ->
        channel
        |> SAService.Stub.regenerate_token(request, opts())
        |> process_response("regenerate_token")
      end
    )
  end

  defp process_response({:ok, response}, _action), do: response |> Util.Proto.to_map()

  defp process_response(
         {:error, %GRPC.RPCError{message: message, status: status}},
         action
       ) do
    cond do
      status in [3, 6, 9] -> ToTuple.user_error(message)
      status == 5 -> ToTuple.not_found_error(message)
      true -> Log.internal_error(message, action, "ServiceAccount")
    end
  end

  defp process_response({:error, error}, action) do
    Logger.error("Error on #{action}: #{inspect(error)}")
    error |> Log.internal_error(action, "ServiceAccount")
  end

  defp process_response(error, action) do
    Logger.error("Error on #{action}: #{inspect(error)}")
    error |> Log.internal_error(action, "ServiceAccount")
  end
end
