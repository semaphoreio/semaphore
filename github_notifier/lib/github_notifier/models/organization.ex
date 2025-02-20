defmodule GithubNotifier.Models.Organization do
  defstruct [:id, :name]

  require Logger

  @spec find(String.t()) :: GithubNotifier.Models.Organization | nil
  def find(id) do
    Watchman.benchmark("fetch_organization.duration", fn ->
      req = InternalApi.Organization.DescribeRequest.new(org_id: id)

      {:ok, channel} =
        GRPC.Stub.connect(Application.fetch_env!(:github_notifier, :organization_grpc_endpoint))

      Logger.debug(fn ->
        "Sending Organization describe request for org_id: #{id}"
      end)

      Logger.debug(inspect(req))

      {:ok, res} =
        InternalApi.Organization.OrganizationService.Stub.describe(channel, req, timeout: 30_000)

      Logger.debug("Received Organization describe response")
      Logger.debug(inspect(res))

      case InternalApi.ResponseStatus.Code.key(res.status.code) do
        :OK -> construct(res.organization)
        _ -> nil
      end
    end)
  end

  defp construct(raw_org) do
    %__MODULE__{
      :id => raw_org.org_id,
      :name => raw_org.org_username
    }
  end
end
