defmodule Auth.FeatureClient do
  @moduledoc """
  Client for communication with the Feature service.
  """
  require Logger

  alias InternalApi.Feature.{
    ListOrganizationFeaturesRequest,
    ListOrganizationMachinesRequest
  }

  alias InternalApi.Feature

  alias Util

  def list_organization_features(org_id),
    do: grpc_call(%ListOrganizationFeaturesRequest{org_id: org_id}, :list_organization_features)

  def list_organization_machines(org_id),
    do: grpc_call(%ListOrganizationMachinesRequest{org_id: org_id}, :list_organization_machines)

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

  defp call_grpc({:error, err} = error, _, _, _, _, _) do
    Logger.error("""
    Unexpected error when connecting to Featurehub: #{inspect(err)}
    """)

    error
  end

  defp call_grpc({:ok, channel}, module, function_name, request, metadata, timeout) do
    apply(module, function_name, [channel, request, [metadata: metadata, timeout: timeout]])
  end

  defp channel do
    Application.fetch_env!(:auth, :feature_grpc_endpoint)
    |> GRPC.Stub.connect()
  end

  defp timeout do
    500
  end

  defp metadata do
    nil
  end
end
