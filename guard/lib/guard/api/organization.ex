defmodule Guard.Api.Organization do
  require Logger

  @list_page_size 10

  def list(next_page_token \\ "") do
    Watchman.benchmark("list_organizations.duration", fn ->
      req =
        InternalApi.Organization.ListRequest.new(
          order: InternalApi.Organization.ListRequest.Order.value(:BY_CREATION_TIME_ASC),
          page_size: @list_page_size,
          next_page_token: next_page_token
        )

      {:ok, res} =
        InternalApi.Organization.OrganizationService.Stub.list(channel(), req, timeout: 30_000)

      if res.status.code == 0 do
        res.organizations
      else
        []
      end
    end)
  end

  def fetch(org_id) do
    Watchman.benchmark("fetch_organization.duration", fn ->
      req = InternalApi.Organization.DescribeRequest.new(org_id: org_id)

      {:ok, res} =
        InternalApi.Organization.OrganizationService.Stub.describe(channel(), req, timeout: 30_000)

      if res.status.code == 0 do
        res.organization
      else
        nil
      end
    end)
  end

  defp channel do
    {:ok, channel} =
      GRPC.Stub.connect(Application.fetch_env!(:guard, :organization_grpc_endpoint))

    channel
  end
end
