defmodule Guard.Api.Okta do
  require Logger
  alias InternalApi.Okta

  def fetch_for_org(org_id) do
    Logger.info("Fetching Okta integrations for organization #{org_id}")

    req = Okta.ListRequest.new(org_id: org_id)

    case Okta.Okta.Stub.list(channel(), req, timeout: 30_000) do
      {:ok, res} -> res.integrations
      {:error, _reason} -> []
    end
  end

  def fetch_for_first_org do
    Logger.info("Fetching Okta integrations for the first organization")
    first_organization = Guard.Api.Organization.list() |> hd()

    fetch_for_org(first_organization.org_id)
  end

  defp channel do
    {:ok, channel} = GRPC.Stub.connect(Application.fetch_env!(:guard, :okta_grpc_endpoint))
    channel
  end
end
