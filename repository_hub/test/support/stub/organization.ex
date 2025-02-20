defmodule RepositoryHub.Stub.Organization do
  @moduledoc false

  alias InternalApi.Organization.{
    DescribeRequest,
    DescribeResponse,
    Organization
  }

  use GRPC.Server, service: InternalApi.Organization.OrganizationService.Service

  @suspended_org "15dc44f0-3d9e-4282-b474-11959e647f18"

  @spec describe(DescribeRequest.t(), any) :: DescribeResponse.t()
  def describe(request, _stream) do
    %DescribeResponse{
      status: %InternalApi.ResponseStatus{code: :OK},
      organization: struct(Organization, organization_params(request.org_id))
    }
  end

  defp organization_params(@suspended_org) do
    default_org_params(@suspended_org)
    |> Keyword.put(:suspended, true)
  end

  defp organization_params(org_id) do
    default_org_params(org_id)
  end

  defp default_org_params(org_id) do
    [
      org_username: "#{org_id}-username",
      created_at: %Google.Protobuf.Timestamp{seconds: 0, nanos: 0},
      avatar_url: "",
      org_id: org_id,
      name: "my org",
      owner_id: Ecto.UUID.generate(),
      suspended: false,
      open_source: false,
      verified: true,
      restricted: false,
      ip_allow_list: [],
      quotas: []
    ]
  end
end
