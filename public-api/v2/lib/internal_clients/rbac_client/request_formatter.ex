defmodule InternalClients.RBACClient.RequestFormatter do
  @moduledoc """
  Module formats the request using data received into protobuf
  messages suitable for gRPC communication with Guard RBAC service.
  """

  alias InternalApi.RBAC
  alias PublicAPI.Util.ToTuple

  def form_list_project_members_request(_params = %{org_id: org_id, project_id: project_id}) do
    %RBAC.ListMembersRequest{
      org_id: org_id,
      project_id: project_id,
      member_name_contains: ""
    }
    |> ToTuple.ok()
  end

  def form_list_project_members_request(
        _params = %{"org_id" => org_id, "project_id" => project_id}
      ) do
    %RBAC.ListMembersRequest{
      org_id: org_id,
      project_id: project_id,
      member_name_contains: ""
    }
    |> ToTuple.ok()
  end

  def form_list_project_members_request(_),
    do:
      ToTuple.user_error(
        "organization id and project id are required to make list project members request"
      )

  def form_list_roles_request(_params = %{org_id: org_id}),
    do:
      %RBAC.ListRolesRequest{
        org_id: org_id,
        scope: InternalApi.RBAC.Scope.value(:SCOPE_PROJECT)
      }
      |> ToTuple.ok()

  def form_list_roles_request(_params = %{"org_id" => org_id}),
    do:
      %RBAC.ListRolesRequest{
        org_id: org_id,
        scope: InternalApi.RBAC.Scope.value(:SCOPE_PROJECT)
      }
      |> ToTuple.ok()

  def form_list_roles_request(_),
    do: ToTuple.user_error("organization id is required to make list roles request")
end
