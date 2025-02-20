defmodule Front.Clients.Gofer do
  require Logger

  alias InternalApi.Gofer.Switch.Stub

  def channel do
    endpoint = Application.fetch_env!(:front, :gofer_grpc_endpoint)

    {:ok, channel} = endpoint |> GRPC.Stub.connect()
    channel
  end

  def timeout do
    Application.get_env(:front, :default_internal_api_request_timeout, 5_000)
  end

  def metadata do
    nil
  end

  def describe(request) do
    Watchman.benchmark("gofer.describe.duration", fn ->
      response =
        channel()
        |> Stub.describe(request, metadata: metadata(), timeout: timeout())

      case response do
        {:ok, _} -> Watchman.increment("gofer.describe.success")
        {:error, _} -> Watchman.increment("gofer.describe.failure")
      end

      Logger.debug(fn ->
        """
        Gofer API describe returned response
        #{inspect(response)}
        for request
        #{inspect(request)}
        """
      end)

      response
    end)
  end

  def describe_many(request) do
    Watchman.benchmark("gofer.describe_many.duration", fn ->
      response =
        channel()
        |> Stub.describe_many(request, metadata: metadata(), timeout: timeout())

      case response do
        {:ok, _} -> Watchman.increment("gofer.describe_many.success")
        {:error, _} -> Watchman.increment("gofer.describe_many.failure")
      end

      Logger.debug(fn ->
        """
        Gofer API describe_many returned response
        #{inspect(response)}
        for request
        #{inspect(request)}
        """
      end)

      response
    end)
  end

  def trigger(request) do
    Watchman.benchmark("gofer.trigger.duration", fn ->
      response =
        channel()
        |> Stub.trigger(request, metadata: metadata(), timeout: timeout())

      case response do
        {:ok, _} -> Watchman.increment("gofer.trigger.success")
        {:error, _} -> Watchman.increment("gofer.trigger.failure")
      end

      Logger.debug(fn ->
        """
        Gofer API trigger returned response
        #{inspect(response)}
        for request
        #{inspect(request)}
        """
      end)

      response
    end)
  end
end
