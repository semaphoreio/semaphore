defmodule Front.Clients.ServiceAccount do
  require Logger

  alias InternalApi.ServiceAccount.{
    CreateRequest,
    DeleteRequest,
    DescribeRequest,
    ListRequest,
    RegenerateTokenRequest,
    UpdateRequest
  }

  alias Front.Models.ServiceAccount

  @behaviour Front.ServiceAccount.Behaviour

  @impl Front.ServiceAccount.Behaviour
  def create(org_id, name, description, creator_id, role_id) do
    %CreateRequest{
      org_id: org_id,
      name: name,
      description: description,
      creator_id: creator_id,
      role_id: role_id
    }
    |> grpc_call(:create)
    |> case do
      {:ok, result} ->
        service_account = ServiceAccount.from_proto(result.service_account)
        {:ok, {service_account, result.api_token}}

      err ->
        Logger.error("Error creating service account for org #{org_id}: #{inspect(err)}")
        handle_error(err)
    end
  end

  @impl Front.ServiceAccount.Behaviour
  def list(org_id, page_size, page_token) do
    %ListRequest{
      org_id: org_id,
      page_size: page_size,
      page_token: page_token || ""
    }
    |> grpc_call(:list)
    |> case do
      {:ok, result} ->
        service_accounts = Enum.map(result.service_accounts, &ServiceAccount.from_proto/1)
        next_page_token = if result.next_page_token == "", do: nil, else: result.next_page_token
        {:ok, {service_accounts, next_page_token}}

      err ->
        Logger.error("Error listing service accounts for org #{org_id}: #{inspect(err)}")
        handle_error(err)
    end
  end

  @impl Front.ServiceAccount.Behaviour
  def describe(service_account_id) do
    %DescribeRequest{
      service_account_id: service_account_id
    }
    |> grpc_call(:describe)
    |> case do
      {:ok, result} ->
        service_account = ServiceAccount.from_proto(result.service_account)
        {:ok, service_account}

      err ->
        Logger.error("Error describing service account #{service_account_id}: #{inspect(err)}")
        handle_error(err)
    end
  end

  @impl Front.ServiceAccount.Behaviour
  def update(service_account_id, name, description) do
    %UpdateRequest{
      service_account_id: service_account_id,
      name: name,
      description: description
    }
    |> grpc_call(:update)
    |> case do
      {:ok, result} ->
        service_account = ServiceAccount.from_proto(result.service_account)
        {:ok, service_account}

      err ->
        Logger.error("Error updating service account #{service_account_id}: #{inspect(err)}")
        handle_error(err)
    end
  end

  @impl Front.ServiceAccount.Behaviour
  def delete(service_account_id) do
    %DeleteRequest{
      service_account_id: service_account_id
    }
    |> grpc_call(:delete)
    |> case do
      {:ok, _result} ->
        :ok

      err ->
        Logger.error("Error deleting service account #{service_account_id}: #{inspect(err)}")
        handle_error(err)
    end
  end

  @impl Front.ServiceAccount.Behaviour
  def regenerate_token(service_account_id) do
    %RegenerateTokenRequest{
      service_account_id: service_account_id
    }
    |> grpc_call(:regenerate_token)
    |> case do
      {:ok, result} ->
        {:ok, result.api_token}

      err ->
        Logger.error(
          "Error regenerating token for service account #{service_account_id}: #{inspect(err)}"
        )

        handle_error(err)
    end
  end

  defp grpc_call(request, action) do
    Watchman.benchmark("service_account.#{action}.duration", fn ->
      channel()
      |> call_grpc(
        InternalApi.ServiceAccount.ServiceAccountService.Stub,
        action,
        request,
        metadata(),
        timeout()
      )
      |> tap(fn
        {:ok, _} -> Watchman.increment("service_account.#{action}.success")
        {:error, _} -> Watchman.increment("service_account.#{action}.failure")
      end)
    end)
  end

  defp call_grpc(error = {:error, err}, _, _, _, _, _) do
    Logger.error("""
    Unexpected error when connecting to ServiceAccount: #{inspect(err)}
    """)

    error
  end

  defp call_grpc({:ok, channel}, module, function_name, request, metadata, timeout) do
    apply(module, function_name, [channel, request, [metadata: metadata, timeout: timeout]])
  end

  defp channel do
    Application.fetch_env!(:front, :service_account_grpc_endpoint)
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
