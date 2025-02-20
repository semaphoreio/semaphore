defmodule Zebra.Workers.JobRequestFactory.Organization do
  require Logger

  def find(org_id) do
    Watchman.benchmark("zebra.external.organization.describe", fn ->
      alias InternalApi.Organization.DescribeRequest, as: Request
      alias InternalApi.Organization.OrganizationService.Stub

      with req <- Request.new(org_id: org_id),
           {:ok, endpoint} <- Application.fetch_env(:zebra, :organization_api_endpoint),
           {:ok, channel} <- GRPC.Stub.connect(endpoint),
           {:ok, res} <- Stub.describe(channel, req, timeout: 30_000) do
        if res.status.code == 0 do
          {:ok, res.organization}
        else
          Watchman.increment("external.organization.describe.failed")
          Logger.info("Failed to fetch info for org #{org_id}, #{inspect(res.status)}")

          {:stop_job_processing, "Organization #{org_id} not found"}
        end
      else
        e ->
          Logger.info("Failed to fetch info for org #{org_id}, #{inspect(e)}")

          {:error, :communication_error}
      end
    end)
  end
end
