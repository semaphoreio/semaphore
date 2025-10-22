defmodule Front.Clients.EphemeralEnvironments do
  require Logger

  alias InternalApi.EphemeralEnvironments.{
    DescribeRequest,
    ListRequest,
    CreateRequest,
    DeleteRequest,
    CordonRequest,
    UpdateRequest
  }

  @behaviour Front.EphemeralEnvironments.Behaviour

  @impl Front.EphemeralEnvironments.Behaviour
  def list(org_id, project_id) do
    %ListRequest{
      org_id: org_id,
      project_id: project_id
    }
    |> grpc_call(:list)
    |> case do
      {:ok, result} ->
        {:ok, result.environment_types}

      err ->
        Logger.error(
          "Error listing ephemeral environments for org #{org_id}, project #{project_id}: #{inspect(err)}"
        )

        handle_error(err)
    end
  end

  @impl Front.EphemeralEnvironments.Behaviour
  def describe(id, org_id) do
    %DescribeRequest{
      id: id,
      org_id: org_id
    }
    |> grpc_call(:describe)
    |> case do
      {:ok, result} ->
        {:ok, result.environment_type}

      err ->
        Logger.error(
          "Error describing ephemeral environment for org #{org_id}, id #{id}: #{inspect(err)}"
        )

        handle_error(err)
    end
  end

  @impl Front.EphemeralEnvironments.Behaviour
  def create(environment_type) do
    %CreateRequest{
      environment_type: environment_type
    }
    |> grpc_call(:create)
    |> case do
      {:ok, result} ->
        {:ok, result.environment_type}

      err ->
        Logger.error("Error creating ephemeral environment: #{inspect(err)}")
        handle_error(err)
    end
  end

  @impl Front.EphemeralEnvironments.Behaviour
  def delete(id, org_id) do
    %DeleteRequest{
      id: id,
      org_id: org_id
    }
    |> grpc_call(:delete)
    |> case do
      {:ok, _result} ->
        :ok

      err ->
        Logger.error("Error deleting ephemeral environment #{id}: #{inspect(err)}")
        handle_error(err)
    end
  end

  @impl Front.EphemeralEnvironments.Behaviour
  def update(environment_type) do
    %UpdateRequest{
      environment_type: environment_type
    }
    |> grpc_call(:update)
    |> case do
      {:ok, result} ->
        {:ok, result.environment_type}

      err ->
        Logger.error("Error updating ephemeral environment: #{inspect(err)}")
        handle_error(err)
    end
  end

  @impl Front.EphemeralEnvironments.Behaviour
  def cordon(id, org_id) do
    %CordonRequest{
      id: id,
      org_id: org_id
    }
    |> grpc_call(:cordon)
    |> case do
      {:ok, result} ->
        {:ok, result.environment_type}

      err ->
        Logger.error("Error cordoning ephemeral environment #{id}: #{inspect(err)}")
        handle_error(err)
    end
  end

  defp grpc_call(request, action) do
    Watchman.benchmark("ephemeral_environments.#{action}.duration", fn ->
      channel()
      |> call_grpc(
        InternalApi.EphemeralEnvironments.EphemeralEnvironments.Stub,
        action,
        request,
        metadata(),
        timeout()
      )
      |> tap(fn
        {:ok, _} -> Watchman.increment("ephemeral_environments.#{action}.success")
        {:error, _} -> Watchman.increment("ephemeral_environments.#{action}.failure")
      end)
    end)
  end

  defp call_grpc(error = {:error, err}, _, _, _, _, _) do
    Logger.error("""
    Unexpected error when connecting to EphemeralEnvironments: #{inspect(err)}
    """)

    error
  end

  defp call_grpc({:ok, channel}, module, function_name, request, metadata, timeout) do
    apply(module, function_name, [channel, request, [metadata: metadata, timeout: timeout]])
  end

  defp channel do
    Application.fetch_env!(:front, :ephemeral_environments_grpc_endpoint)
    |> GRPC.Stub.connect()
  end

  defp timeout do
    15_000
  end

  defp metadata do
    nil
  end

  defp handle_error({:error, %GRPC.RPCError{status: status, message: message}}) do
    if status == GRPC.Status.internal() do
      {:error, "Unknown error, if this persists, please contact support."}
    else
      {:error, message}
    end
  end

  defp handle_error({:error, _}) do
    {:error, "Unknown error, if this persists, please contact support."}
  end
end
