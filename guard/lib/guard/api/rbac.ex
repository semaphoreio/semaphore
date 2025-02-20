defmodule Guard.Api.Rbac do
  @list_page_size 100

  def list_members(org_id, project_id \\ ""), do: do_list_members(org_id, project_id, 1, [])

  defp do_list_members(org_id, project_id, page_no, acc) do
    req = build_list_members_request(org_id, project_id, page_no)

    {:ok, response} = InternalApi.RBAC.RBAC.Stub.list_members(channel(), req, timeout: 30_000)

    if response.total_pages > page_no do
      do_list_members(org_id, project_id, page_no + 1, acc ++ response.members)
    else
      acc ++ response.members
    end
  end

  def no_of_members(org_id), do: do_no_of_members(org_id, 1, 0)

  defp do_no_of_members(org_id, page_no, acc) do
    req = build_list_members_request(org_id, "", page_no)

    {:ok, response} = InternalApi.RBAC.RBAC.Stub.list_members(channel(), req, timeout: 30_000)
    members_count = Enum.count(response.members)

    # if there is more than one page it is possible to calculate
    # the total number of members until the last page. Then we
    # add the number of members from the last page. This will make us not
    # have to request each page to get the total number of members.
    if response.total_pages > page_no do
      members_count = @list_page_size * (response.total_pages - 1)
      do_no_of_members(org_id, response.total_pages, members_count)
    else
      acc + members_count
    end
  end

  defp build_list_members_request(org_id, project_id, page) do
    InternalApi.RBAC.ListMembersRequest.new(
      org_id: org_id,
      project_id: project_id,
      member_type: InternalApi.RBAC.SubjectType.value(:USER),
      page:
        InternalApi.RBAC.ListMembersRequest.Page.new(
          page_no: page,
          page_size: @list_page_size
        )
    )
  end

  def assign_org_role_by_name(org_id, user_id, role_name) do
    role_id = get_role_id(org_id, role_name, :SCOPE_ORG)
    assign_role(org_id, user_id, role_id)
  end

  def user_part_of_org?(user_id, org_id) do
    req = InternalApi.RBAC.ListAccessibleOrgsRequest.new(user_id: user_id)

    {:ok, response} =
      InternalApi.RBAC.RBAC.Stub.list_accessible_orgs(channel(), req, timeout: 30_000)

    Enum.member?(response.org_ids, org_id)
  end

  defp get_role_id(org_id, role_name, scope) do
    roles = list_roles(org_id, scope)

    role =
      Enum.find(roles, fn role ->
        role.name == role_name
      end)

    if role, do: role.id, else: nil
  end

  defp list_roles(org_id, scope) do
    req =
      InternalApi.RBAC.ListRolesRequest.new(
        org_id: org_id,
        scope: InternalApi.RBAC.Scope.value(scope)
      )

    {:ok, response} = InternalApi.RBAC.RBAC.Stub.list_roles(channel(), req, timeout: 30_000)
    response.roles
  end

  def list_user_permissions(user_id, org_id, project_id \\ "") do
    req =
      InternalApi.RBAC.ListUserPermissionsRequest.new(
        org_id: org_id,
        user_id: user_id,
        project_id: project_id
      )

    {:ok, response} =
      InternalApi.RBAC.RBAC.Stub.list_user_permissions(channel(), req, timeout: 30_000)

    response.permissions
  end

  def list_accessible_projects(org_id, user_id) do
    req = InternalApi.RBAC.ListAccessibleProjectsRequest.new(org_id: org_id, user_id: user_id)

    {:ok, response} =
      InternalApi.RBAC.RBAC.Stub.list_accessible_projects(channel(), req, timeout: 30_000)

    response.project_ids
  end

  def assign_role(org_id, user_id, role_id) do
    org = Guard.Api.Organization.fetch(org_id)

    req =
      InternalApi.RBAC.AssignRoleRequest.new(
        requester_id: org.owner_id,
        role_assignment:
          InternalApi.RBAC.RoleAssignment.new(
            subject:
              InternalApi.RBAC.Subject.new(
                subject_id: user_id,
                subject_type: InternalApi.RBAC.SubjectType.value(:USER)
              ),
            org_id: org_id,
            role_id: role_id
          )
      )

    {:ok, _response} = InternalApi.RBAC.RBAC.Stub.assign_role(channel(), req, timeout: 30_000)

    :ok
  end

  defp channel do
    {:ok, channel} = GRPC.Stub.connect(Application.fetch_env!(:guard, :rbac_grpc_endpoint))

    channel
  end
end
