defmodule Projecthub.Organization do
  alias InternalApi.Organization.OrganizationService.Stub, as: Client
  alias InternalApi.Organization.RepositoryIntegratorsRequest
  alias InternalApi.Organization.DescribeRequest

  require Logger

  def primary_integration_type(org_id) do
    {:ok, channel} = get_channel()
    req = RepositoryIntegratorsRequest.new(org_id: org_id)

    case Client.repository_integrators(channel, req, timeout: 30_000) do
      {:ok, res} ->
        res.primary

      _ ->
        0
    end
  end

  def restricted?(org_id) do
    {:ok, channel} = get_channel()
    req = DescribeRequest.new(org_id: org_id)

    {:ok, rsp} = Client.describe(channel, req, timeout: 30_000)

    case InternalApi.ResponseStatus.Code.key(rsp.status.code) do
      :OK -> rsp.organization.restricted
      _ -> false
    end
  end

  defp get_channel do
    GRPC.Stub.connect(Application.fetch_env!(:projecthub, :organization_grpc_endpoint))
  end
end
