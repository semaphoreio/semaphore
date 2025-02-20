defmodule Rbac.Api.Organization do
  require Logger
  alias InternalApi.Organization

  def get(id) do
    req = %Organization.DescribeRequest{org_id: id}

    {:ok, channel} =
      GRPC.Stub.connect(Application.fetch_env!(:rbac, :organization_grpc_endpoint))

    Logger.info("Sending Organization describe request for org id: #{id}")
    Logger.info(inspect(req))

    grpc_result = Organization.OrganizationService.Stub.describe(channel, req, timeout: 30_000)

    Logger.info("Received Organization describe response")
    Logger.info(inspect(grpc_result))

    case grpc_result do
      {:ok, res} when res.status.code == :OK ->
        {:ok, res.organization}

      {:error, _} ->
        {:error, :not_found}
    end
  end
end
