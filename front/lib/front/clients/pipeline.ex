defmodule Front.Clients.Pipeline do
  require Logger
  alias InternalApi.Plumber.PipelineService.Stub

  def channel do
    endpoint = Application.fetch_env!(:front, :pipeline_api_grpc_endpoint)

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
    Watchman.benchmark("pipeline.describe.duration", fn ->
      response =
        channel()
        |> Stub.describe(request, metadata: metadata(), timeout: timeout())

      case response do
        {:ok, _} -> Watchman.increment("pipeline.describe.success")
        {:error, _} -> Watchman.increment("pipeline.describe.failure")
      end

      Logger.debug(fn ->
        """
        Pipeline API describe returned response
        #{inspect(response)}
        for request
        #{inspect(request)}
        """
      end)

      response
    end)
  end

  def describe_many(request) do
    Watchman.benchmark("pipeline.describe_many.duration", fn ->
      response =
        channel()
        |> Stub.describe_many(request, metadata: metadata(), timeout: timeout())

      case response do
        {:ok, _} -> Watchman.increment("pipeline.describe_many.success")
        {:error, _} -> Watchman.increment("pipeline.describe_many.failure")
      end

      Logger.debug(fn ->
        """
        Pipeline API describe_many returned response
        #{inspect(response)}
        for request
        #{inspect(request)}
        """
      end)

      response
    end)
  end

  def describe_topology(request) do
    Watchman.benchmark("pipeline.describe_topology.duration", fn ->
      response =
        channel()
        |> Stub.describe_topology(request, metadata: metadata(), timeout: timeout())

      case response do
        {:ok, _} -> Watchman.increment("pipeline.describe_topology.success")
        {:error, _} -> Watchman.increment("pipeline.describe_topology.failure")
      end

      Logger.debug(fn ->
        """
        Pipeline API describe_topology returned response
        #{inspect(response)}
        for request
        #{inspect(request)}
        """
      end)

      response
    end)
  end

  def list(request) do
    Watchman.benchmark("pipeline.list.duration", fn ->
      response =
        channel()
        |> Stub.list(request, metadata: metadata(), timeout: timeout())

      case response do
        {:ok, _} -> Watchman.increment("pipeline.list.success")
        {:error, _} -> Watchman.increment("pipeline.list.failure")
      end

      Logger.debug(fn ->
        """
        Pipeline API list returned response
        #{inspect(response)}
        for request
        #{inspect(request)}
        """
      end)

      response
    end)
  end

  def list_keyset(request) do
    Watchman.benchmark("pipeline.list_keyset.duration", fn ->
      response =
        channel()
        |> Stub.list_keyset(request, metadata: metadata(), timeout: timeout())

      case response do
        {:ok, _} -> Watchman.increment("pipeline.list_keyset.success")
        {:error, _} -> Watchman.increment("pipeline.list_keyset.failure")
      end

      Logger.debug(fn ->
        """
        pipeline API list_keyset returned response
        #{inspect(response)}
        for request
        #{inspect(request)}
        """
      end)

      response
    end)
  end

  def terminate(request) do
    Watchman.benchmark("pipeline.terminate.duration", fn ->
      response =
        channel()
        |> Stub.terminate(request, metadata: metadata(), timeout: timeout())

      case response do
        {:ok, _} -> Watchman.increment("pipeline.terminate.success")
        {:error, _} -> Watchman.increment("pipeline.terminate.failure")
      end

      Logger.debug(fn ->
        """
        Pipeline API terminate returned response
        #{inspect(response)}
        for request
        #{inspect(request)}
        """
      end)

      response
    end)
  end

  def list_activity(request) do
    Watchman.benchmark("pipeline.list_activity.duration", fn ->
      response =
        channel()
        |> Stub.list_activity(request, metadata: metadata(), timeout: timeout())

      case response do
        {:ok, _} -> Watchman.increment("pipeline.list_activity.success")
        {:error, _} -> Watchman.increment("pipeline.list_activity.failure")
      end

      Logger.debug(fn ->
        """
        Pipeline API list activity returned response
        #{inspect(response)}
        for request
        #{inspect(request)}
        """
      end)

      response
    end)
  end

  def partial_rebuild(request) do
    Watchman.benchmark("pipeline.partial_rebuild.duration", fn ->
      response =
        channel()
        |> Stub.partial_rebuild(request, metadata: metadata(), timeout: timeout())

      case response do
        {:ok, _} -> Watchman.increment("pipeline.partial_rebuild.success")
        {:error, _} -> Watchman.increment("pipeline.partial_rebuild.failure")
      end

      Logger.debug(fn ->
        """
        Pipeline API partial_rebuild returned response
        #{inspect(response)}
        for request
        #{inspect(request)}
        """
      end)

      response
    end)
  end
end
