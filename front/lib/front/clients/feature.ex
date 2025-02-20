defmodule Front.Clients.Feature do
  @moduledoc """
  Client for communication with the Feature service.
  """
  require Logger

  alias Util.Proto

  alias InternalApi.Feature.{
    ListFeaturesRequest,
    ListFeaturesResponse,
    ListMachinesRequest,
    ListMachinesResponse,
    ListOrganizationFeaturesRequest,
    ListOrganizationFeaturesResponse,
    ListOrganizationMachinesRequest,
    ListOrganizationMachinesResponse
  }

  alias InternalApi.Feature

  alias Util

  @type rpc_request(response_type) :: response_type | Map.t()
  @type rpc_response(response_type) :: {:ok, response_type} | {:error, GRPC.RPCError.t()}

  @spec list_organization_features(rpc_request(ListOrganizationFeaturesRequest.t())) ::
          rpc_response(ListOrganizationFeaturesResponse.t())
  def list_organization_features(request),
    do:
      request
      |> decorate(ListOrganizationFeaturesRequest)
      |> grpc_call(:list_organization_features)

  @spec list_features(rpc_request(ListFeaturesRequest.t())) ::
          rpc_response(ListFeaturesResponse.t())
  def list_features(request),
    do:
      request
      |> decorate(ListFeaturesRequest)
      |> grpc_call(:list_features)

  @spec list_organization_machines(rpc_request(ListOrganizationMachinesRequest.t())) ::
          rpc_response(ListOrganizationMachinesResponse.t())
  def list_organization_machines(request),
    do:
      request
      |> decorate(ListOrganizationMachinesRequest)
      |> grpc_call(:list_organization_machines)

  @spec list_machines(rpc_request(ListMachinesRequest.t())) ::
          rpc_response(ListMachinesResponse.t())
  def list_machines(request),
    do:
      request
      |> decorate(ListMachinesRequest)
      |> grpc_call(:list_machines)

  defp decorate(request, schema) when is_struct(request, schema) do
    request
  end

  defp decorate(request, schema) do
    Proto.deep_new!(request, schema)
  end

  defp grpc_call(request, action) do
    Watchman.benchmark("feature_hub.#{action}.duration", fn ->
      channel()
      |> call_grpc(Feature.FeatureService.Stub, action, request, metadata(), timeout())
      |> tap(fn
        {:ok, _} -> Watchman.increment("feature_hub.#{action}.success")
        {:error, _} -> Watchman.increment("feature_hub.#{action}.failure")
      end)
    end)
  end

  defp call_grpc(error = {:error, err}, _, _, _, _, _) do
    Logger.error("""
    Unexpected error when connecting to Featurehub: #{inspect(err)}
    """)

    error
  end

  defp call_grpc({:ok, channel}, module, function_name, request, metadata, timeout) do
    apply(module, function_name, [channel, request, [metadata: metadata, timeout: timeout]])
  end

  defp channel do
    Application.fetch_env!(:front, :feature_grpc_endpoint)
    |> GRPC.Stub.connect()
  end

  defp timeout do
    500
  end

  defp metadata do
    nil
  end
end
