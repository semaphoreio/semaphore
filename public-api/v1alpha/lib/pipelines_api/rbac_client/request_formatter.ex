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

  def form_list_project_members_request(params = %{org_id: org_id, project_id: project_id}) do
    ToTuple.ok(
      RBAC.ListMembersRequest.new(
        org_id: org_id,
        project_id: project_id,
        member_name_contains: "",
        page: build_page(params),
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

  def form_retract_role_request(
        params = %{user_id: user_id, org_id: org_id, requester_id: requester_id}
      ) do
    ToTuple.ok(
      RBAC.RetractRoleRequest.new(
        role_assignment:
          RBAC.RoleAssignment.new(
            subject: RBAC.Subject.new(subject_id: user_id),
            org_id: org_id,
            role_id: Map.get(params, :role_id) || ""
          ),
        requester_id: requester_id
      )
    )
  end

  def form_retract_role_request(_),
    do: ToTuple.user_error("Bad retract role request")

  def form_retract_project_role_request(
        params = %{
          user_id: user_id,
          org_id: org_id,
          project_id: project_id,
          requester_id: requester_id
        }
      ) do
    ToTuple.ok(
      RBAC.RetractRoleRequest.new(
        role_assignment:
          RBAC.RoleAssignment.new(
            subject: RBAC.Subject.new(subject_id: user_id),
            org_id: org_id,
            project_id: project_id,
            role_id: Map.get(params, :role_id) || ""
          ),
        requester_id: requester_id
      )
    )
  end

  def form_retract_project_role_request(_),
    do: ToTuple.user_error("Bad retract project role request")

  def form_list_org_members_request(params = %{org_id: org_id}) do
    ToTuple.ok(
      RBAC.ListMembersRequest.new(
        org_id: org_id,
        project_id: "",
        member_name_contains: "",
        member_has_role: "",
        page: build_page(params),
        member_type: subject_type_value(Map.get(params, :member_type))
      )
    )
  end

  def form_list_org_members_request(_),
    do: ToTuple.user_error("organization id is required")

  # Builds a pagination page from optional :page_no / :page_size params,
  # falling back to a sane default page size when the client omits it.
  defp build_page(params) do
    page_no = Map.get(params, :page_no) || 0
    page_size = Map.get(params, :page_size) || @total_page_size

    RBAC.ListMembersRequest.Page.new(page_no: page_no, page_size: page_size)
  end

  defp subject_type_value(t) when t in ["service_account", "SERVICE_ACCOUNT"],
    do: RBAC.SubjectType.value(:SERVICE_ACCOUNT)

  defp subject_type_value(t) when t in ["group", "GROUP"],
    do: RBAC.SubjectType.value(:GROUP)

  defp subject_type_value(_), do: RBAC.SubjectType.value(:USER)

  def form_list_org_roles_request(%{org_id: org_id}) do
    ToTuple.ok(
      RBAC.ListRolesRequest.new(
        org_id: org_id,
        scope: RBAC.Scope.value(:SCOPE_ORG)
      )
    )
  end

  def form_list_org_roles_request(_),
    do: ToTuple.user_error("organization id is required")

  def form_describe_role_request(%{role_id: role_id, org_id: org_id}) do
    ToTuple.ok(
      RBAC.DescribeRoleRequest.new(
        role_id: role_id,
        org_id: org_id
      )
    )
  end

  def form_describe_role_request(_),
    do: ToTuple.user_error("role_id and org_id are required")

  def form_modify_role_request(%{role: role, requester_id: requester_id}) do
    ToTuple.ok(RBAC.ModifyRoleRequest.new(role: role, requester_id: requester_id))
  end

  def form_modify_role_request(_),
    do: ToTuple.user_error("role and requester_id are required")

  def form_destroy_role_request(%{role_id: role_id, org_id: org_id, requester_id: requester_id}) do
    ToTuple.ok(
      RBAC.DestroyRoleRequest.new(
        role_id: role_id,
        org_id: org_id,
        requester_id: requester_id
      )
    )
  end

  def form_destroy_role_request(_),
    do: ToTuple.user_error("role_id, org_id, and requester_id are required")

  def form_assign_role_request(%{
        role_id: role_id,
        org_id: org_id,
        project_id: project_id,
        subject_id: subject_id,
        requester_id: requester_id
      }) do
    ToTuple.ok(
      RBAC.AssignRoleRequest.new(
        role_assignment:
          RBAC.RoleAssignment.new(
            role_id: role_id,
            subject: RBAC.Subject.new(subject_id: subject_id),
            org_id: org_id,
            project_id: project_id || ""
          ),
        requester_id: requester_id
      )
    )
  end

  def form_assign_role_request(_),
    do: ToTuple.user_error("role_id, org_id, subject_id, and requester_id are required")

  def form_list_existing_permissions_request(%{scope: scope}) do
    ToTuple.ok(RBAC.ListExistingPermissionsRequest.new(scope: scope))
  end

  def form_list_existing_permissions_request(_),
    do: ToTuple.user_error("scope is required")
end
