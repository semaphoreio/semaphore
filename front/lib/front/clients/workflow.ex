defmodule Front.Clients.Workflow do
  require Logger
  alias InternalApi.PlumberWF.WorkflowService.Stub

  def channel do
    endpoint = Application.fetch_env!(:front, :workflow_api_grpc_endpoint)
    endpoint |> GRPC.Stub.connect()
  end

  def timeout do
    Application.get_env(:front, :default_internal_api_request_timeout, 5_000)
  end

  def metadata do
    nil
  end

  def describe(request) do
    Watchman.benchmark("workflow.describe.duration", fn ->
      response =
        with {:ok, channel} <- channel() do
          Stub.describe(channel, request, metadata: metadata(), timeout: timeout())
        end

      case response do
        {:ok, _} -> Watchman.increment("workflow.describe.success")
        {:error, _} -> Watchman.increment("workflow.describe.failure")
      end

      Logger.debug(fn ->
        """
        workflow API describe returned response
        #{inspect(response)}
        for request
        #{inspect(request)}
        """
      end)

      response
    end)
  end

  def describe_many(request) do
    Watchman.benchmark("workflow.describe_many.duration", fn ->
      response =
        with {:ok, channel} <- channel() do
          Stub.describe_many(channel, request, metadata: metadata(), timeout: timeout())
        end

      case response do
        {:ok, _} -> Watchman.increment("workflow.describe_many.success")
        {:error, _} -> Watchman.increment("workflow.describe_many.failure")
      end

      Logger.debug(fn ->
        """
        workflow API describe_many returned response
        #{inspect(response)}
        for request
        #{inspect(request)}
        """
      end)

      response
    end)
  end

  def list(request) do
    Watchman.benchmark("workflow.list.duration", fn ->
      response =
        with {:ok, channel} <- channel() do
          Stub.list(channel, request, metadata: metadata(), timeout: timeout())
        end

      case response do
        {:ok, _} -> Watchman.increment("workflow.list.success")
        {:error, _} -> Watchman.increment("workflow.list.failure")
      end

      Logger.debug(fn ->
        """
        workflow API list returned response
        #{inspect(response)}
        for request
        #{inspect(request)}
        """
      end)

      response
    end)
  end

  def list_keyset(request) do
    Watchman.benchmark("workflow.list_keyset.duration", fn ->
      response =
        with {:ok, channel} <- channel() do
          Stub.list_keyset(channel, request, metadata: metadata(), timeout: timeout())
        end

      case response do
        {:ok, _} ->
          Watchman.increment("workflow.list_keyset.success")

        {:error, message} ->
          Logger.error(
            "Workflow list_keyest failed: #{inspect(message)}; req: #{inspect(request)}"
          )

          Watchman.increment("workflow.list_keyset.failure")
      end

      Logger.debug(fn ->
        """
        workflow API list_keyset returned response
        #{inspect(response)}
        for request
        #{inspect(request)}
        """
      end)

      response
    end)
  end

  def list_latest_workflows(request) do
    Watchman.benchmark({"workflow.list_latest_workflows.duration", [request.project_id]}, fn ->
      response =
        with {:ok, channel} <- channel() do
          Stub.list_latest_workflows(channel, request, metadata: metadata(), timeout: timeout())
        end

      case response do
        {:ok, _} -> Watchman.increment("workflow.list_latest_workflows.success")
        {:error, _} -> Watchman.increment("workflow.list_latest_workflows.failure")
      end

      Logger.debug(fn ->
        """
        workflow API list_latest_workflows returned response
        #{inspect(response)}
        for request
        #{inspect(request)}
        """
      end)

      response
    end)
  end

  def reschedule(request) do
    Watchman.benchmark("workflow.reschedule.duration", fn ->
      response =
        with {:ok, channel} <- channel() do
          Stub.reschedule(channel, request, metadata: metadata(), timeout: timeout())
        end

      case response do
        {:ok, _} -> Watchman.increment("workflow.reschedule.success")
        {:error, _} -> Watchman.increment("workflow.reschedule.failure")
      end

      Logger.debug(fn ->
        """
        workflow API reschedule returned response
        #{inspect(response)}
        for request
        #{inspect(request)}
        """
      end)

      response
    end)
  end

  def get_path(request) do
    Watchman.benchmark("workflow.get_path.duration", fn ->
      response =
        with {:ok, channel} <- channel() do
          Stub.get_path(channel, request, metadata: metadata(), timeout: timeout())
        end

      case response do
        {:ok, _} -> Watchman.increment("workflow.get_path.success")
        {:error, _} -> Watchman.increment("workflow.get_path.failure")
      end

      Logger.debug(fn ->
        """
        workflow API get_path returned response
        #{inspect(response)}
        for request
        #{inspect(request)}
        """
      end)

      response
    end)
  end
end
