defmodule Rbac.Api.Organization do
  require Logger
  alias InternalApi.Organization

  def find_by_username(username) do
    req = %Organization.DescribeRequest{org_username: username}
    describe_organization(req)
  end

  def find_by_id(org_id) do
    req = %Organization.DescribeRequest{org_id: org_id}
    describe_organization(req)
  end

  defp describe_organization(req) do
    {:ok, channel} = GRPC.Stub.connect(Application.fetch_env!(:rbac, :organization_grpc_endpoint))

    Logger.info("Sending Organization describe request: #{inspect(req)}")

    grpc_result = Organization.OrganizationService.Stub.describe(channel, req, timeout: 30_000)

    Logger.info("Received Organization describe response: #{inspect(grpc_result)}")

    case grpc_result do
      {:ok, res} when res.status.code == :OK ->
        {:ok, res.organization}

      {:error, _} ->
        {:error, :not_found}
    end
  end

  def update(organization) do
    req = %Organization.UpdateRequest{organization: organization}
    {:ok, channel} = GRPC.Stub.connect(Application.fetch_env!(:rbac, :organization_grpc_endpoint))

    Logger.info("Sending Organization update request: #{inspect(req)}")

    grpc_result = Organization.OrganizationService.Stub.update(channel, req, timeout: 30_000)

    Logger.info("Received Organization update response: #{inspect(grpc_result)}")

    case grpc_result do
      {:ok, res} -> {:ok, res.organization}
      {:error, error} -> {:error, error}
    end
  end
end
