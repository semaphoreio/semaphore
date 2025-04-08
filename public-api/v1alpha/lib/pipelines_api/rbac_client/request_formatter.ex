defmodule PipelinesAPI.RBACClient.RequestFormatter do
  @moduledoc """
  Module formats the request using data received into protobuf
  messages suitable for gRPC communication with Guard RBAC service.
  """

  alias InternalApi.RBAC
  alias PipelinesAPI.Util.ToTuple

  @total_page_size 2_000

  def form_list_user_permissions(
        _params = %{org_id: org_id, user_id: user_id, project_id: project_id}
      ) do
    ToTuple.ok(
      RBAC.ListUserPermissionsRequest.new(
        org_id: org_id,
        user_id: user_id,
        project_id: project_id
      )
    )
  end

  def form_list_user_permissions(_params = %{org_id: org_id, user_id: user_id}) do
    ToTuple.ok(
      RBAC.ListUserPermissionsRequest.new(
        user_id: user_id,
        org_id: org_id,
        project_id: ""
      )
    )
  end

  def form_list_user_permissions(_),
    do:
      ToTuple.user_error(
        "organization id and user id are required to build list user permissions request"
      )

  def form_list_project_members_request(_params = %{org_id: org_id, project_id: project_id}) do
    ToTuple.ok(
      RBAC.ListMembersRequest.new(
        org_id: org_id,
        project_id: project_id,
        member_name_contains: "",
        page:
          RBAC.ListMembersRequest.Page.new(
            page_no: 0,
            page_size: @total_page_size
          ),
        member_type: RBAC.SubjectType.value(:USER)
      )
    )
  end

  def form_list_project_members_request(
        _params = %{"org_id" => org_id, "project_id" => project_id}
      ) do
    ToTuple.ok(
      RBAC.ListMembersRequest.new(
        org_id: org_id,
        project_id: project_id,
        member_name_contains: "",
        page:
          RBAC.ListMembersRequest.Page.new(
            page_no: 0,
            page_size: @total_page_size
          ),
        member_type: RBAC.SubjectType.value(:USER)
      )
    )
  end

  def form_list_project_members_request(_),
    do:
      ToTuple.user_error(
        "organization id and project id are required to make list project members request"
      )

  def form_list_roles_request(_params = %{org_id: org_id}),
    do:
      ToTuple.ok(
        RBAC.ListRolesRequest.new(
          org_id: org_id,
          scope: InternalApi.RBAC.Scope.value(:SCOPE_PROJECT)
        )
      )

  def form_list_roles_request(_params = %{"org_id" => org_id}),
    do:
      ToTuple.ok(
        RBAC.ListRolesRequest.new(
          org_id: org_id,
          scope: InternalApi.RBAC.Scope.value(:SCOPE_PROJECT)
        )
      )

  def form_list_roles_request(_),
    do: ToTuple.user_error("organization id is required to make list roles request")

  def form_retract_role_request(_params = %{"user_id" => user_id}) do
  end

  def form_retract_role_request(_params = %{"user_email" => user_id}) do
  end

  def form_retract_role_request(_),
    do: ToTuple.user_error("user id is required to make retract role request")
end
