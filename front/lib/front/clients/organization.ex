defmodule Front.Clients.Organization do
  @moduledoc """
  Client for communication with the Organization service.
  """
  require Logger

  alias Util.Proto

  alias InternalApi.Organization.Organization, as: IsValidRequest
  alias InternalApi.Organization.OrganizationService.Stub

  alias InternalApi.Organization.{
    CreateRequest,
    CreateResponse,
    IsValidResponse
  }

  alias Util

  @type rpc_request(response_type) :: response_type | Map.t()
  @type rpc_response(response_type) :: {:ok, response_type} | {:error, GRPC.RPCError.t()}

  @spec create(request :: rpc_request(CreateRequest.t())) ::
          rpc_response(CreateResponse.t())
  def create(request),
    do:
      request
      |> decorate(CreateRequest)
      |> grpc_call(:create)

  @spec is_valid(request :: rpc_request(IsValidRequest.t())) ::
          rpc_response(IsValidResponse.t())
  def is_valid(request),
    do:
      request
      |> decorate(IsValidRequest)
      |> grpc_call(:is_valid)

  defp decorate(request, schema) when is_struct(request, schema) do
    request
  end

  defp decorate(request, schema) do
    Proto.deep_new!(request, schema)
  end

  defp grpc_call(request, action) do
    Watchman.benchmark("organization.#{action}.duration", fn ->
      channel()
      |> call_grpc(Stub, action, request, metadata(), timeout())
      |> tap(fn
        {:ok, _} -> Watchman.increment("organization.#{action}.success")
        {:error, _} -> Watchman.increment("organization.#{action}.failure")
      end)
    end)
  end

  defp call_grpc(error = {:error, err}, _, _, _, _, _) do
    Logger.error("""
    Unexpected error when connecting to OrganizationAPI: #{inspect(err)}
    """)

    error
  end

  defp call_grpc({:ok, channel}, module, function_name, request, metadata, timeout) do
    apply(module, function_name, [channel, request, [metadata: metadata, timeout: timeout]])
  end

  defp channel do
    Application.fetch_env!(:front, :organization_api_grpc_endpoint)
    |> GRPC.Stub.connect()
  end

  defp timeout do
    10_000
  end

  defp metadata do
    nil
  end
end
