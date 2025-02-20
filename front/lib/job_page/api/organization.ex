defmodule JobPage.Api.Organization do
  alias JobPage.GrpcConfig

  def fetch(organization_id, tracing_headers) do
    Watchman.benchmark("fetch_organization.duration", fn ->
      req = InternalApi.Organization.DescribeRequest.new(org_id: organization_id)

      {:ok, channel} = GRPC.Stub.connect(GrpcConfig.endpoint(:organization_api_grpc_endpoint))

      {:ok, response} =
        InternalApi.Organization.OrganizationService.Stub.describe(
          channel,
          req,
          metadata: tracing_headers,
          timeout: 30_000
        )

      if response.status.code == 0 do
        response.organization
      else
        nil
      end
    end)
  end
end
