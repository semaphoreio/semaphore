defmodule Projecthub.Models.Organization do
  defstruct [:id, :username, :open_source]
  require Logger

  def find(id, metadata \\ nil) do
    req = InternalApi.Organization.DescribeRequest.new(org_id: id, include_quotas: true)

    {:ok, res} =
      InternalApi.Organization.OrganizationService.Stub.describe(
        channel(),
        req,
        options(metadata)
      )

    if res.status.code == :OK do
      construct(res.organization)
    else
      nil
    end
  end

  defp construct(raw_org) do
    %__MODULE__{
      :username => raw_org.org_username,
      :id => raw_org.org_id,
      :open_source => raw_org.open_source
    }
  end

  defp channel do
    GRPC.Stub.connect(Application.fetch_env!(:projecthub, :organization_grpc_endpoint),
      interceptors: [
        Projecthub.Util.GRPC.ClientRequestIdInterceptor,
        {
          Projecthub.Util.GRPC.ClientLoggerInterceptor,
          skip_logs_for: ~w(
            describe
            members
          )
        },
        Projecthub.Util.GRPC.ClientRunAsyncInterceptor
      ]
    )
    |> case do
      {:ok, channel} -> channel
      _ -> nil
    end
  end

  defp options(metadata) do
    [timeout: 30_000, metadata: metadata]
  end
end
