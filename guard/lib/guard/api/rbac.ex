defmodule Guard.Api.Rbac do
  require Logger

  @list_page_size 100
  @owner_role_name "Owner"

  def list_members(org_id, project_id \\ ""), do: collect_members(org_id, project_id, "")

  def no_of_members(org_id), do: org_id |> collect_members("", "") |> length()

  @doc """
  Whether the organization has exactly one member. Only the first page is read
  (page 0 maps to offset 0 on both the EE and CE backends), so this stays a
  single request instead of walking the whole membership just to check for one.
  Subject ids are deduped because CE returns a row per role assignment.
  """
  def single_member?(org_id) do
    count =
      org_id
      |> fetch_member_page("", "", 0)
      |> Enum.map(& &1.subject.subject_id)
      |> Enum.uniq()
      |> length()

    {:ok, count == 1}
  rescue
    e ->
      Logger.warning("[Guard.Api.Rbac] member lookup failed for org #{org_id}: #{inspect(e)}")
      {:error, :ownership_unverified}
  end

  @doc """
  Returns `{:ok, subject_ids}` for the users holding the Owner role in the
  organization (deduped). Owners are fetched with a server-side role filter, so
  the cost is proportional to the number of owners rather than to the total
  membership. Returns `{:error, :owner_role_unresolved}` when the org has no
  role named "Owner" (missing/renamed) — callers must fail closed, since
  ownership cannot be proven.
  """
  def org_owner_ids(org_id) do
    case get_role_id(org_id, @owner_role_name, :SCOPE_ORG) do
      nil ->
        Logger.warning(
          "[Guard.Api.Rbac] Owner role not found for org #{org_id}; " <>
            "cannot verify ownership (org may be misconfigured or unprovisioned)"
        )

        {:error, :owner_role_unresolved}

      role_id ->
        ids =
          org_id
          |> collect_members("", role_id)
          |> Enum.map(& &1.subject.subject_id)
          |> Enum.uniq()

        {:ok, ids}
    end
  rescue
    e ->
      Logger.warning("[Guard.Api.Rbac] owner lookup failed for org #{org_id}: #{inspect(e)}")
      {:error, :ownership_unverified}
  end

  # ListMembers pagination differs between editions: EE is 0-based
  # (offset = page_no * size) while CE is 1-based and coerces page_no 0 to 1
  # (so page_no 0 and 1 both return the first page). We therefore cannot trust a
  # fixed page-number convention or `total_pages`. Walk pages from 0, dedup by
  # subject_id (CE repeats the first page), and stop once a page comes back
  # shorter than a full page, which terminates on either backend.
  defp collect_members(org_id, project_id, role_id) do
    {members, _seen} =
      0
      |> Stream.iterate(&(&1 + 1))
      |> Enum.reduce_while({[], MapSet.new()}, fn page_no, {acc, seen} ->
        page = fetch_member_page(org_id, project_id, role_id, page_no)

        {acc, seen} =
          Enum.reduce(page, {acc, seen}, fn member, {acc, seen} ->
            id = member.subject.subject_id

            if MapSet.member?(seen, id),
              do: {acc, seen},
              else: {[member | acc], MapSet.put(seen, id)}
          end)

        if length(page) < @list_page_size,
          do: {:halt, {acc, seen}},
          else: {:cont, {acc, seen}}
      end)

    Enum.reverse(members)
  end

  defp fetch_member_page(org_id, project_id, role_id, page_no) do
    req = build_list_members_request(org_id, project_id, role_id, page_no)

    {:ok, response} = InternalApi.RBAC.RBAC.Stub.list_members(channel(), req, timeout: 30_000)

    response.members
  end

  defp build_list_members_request(org_id, project_id, role_id, page) do
    InternalApi.RBAC.ListMembersRequest.new(
      org_id: org_id,
      project_id: project_id,
      member_has_role: role_id,
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
    Enum.member?(list_accessible_org_ids(user_id), org_id)
  end

  def list_accessible_org_ids(user_id) do
    req = InternalApi.RBAC.ListAccessibleOrgsRequest.new(user_id: user_id)

    {:ok, response} =
      InternalApi.RBAC.RBAC.Stub.list_accessible_orgs(channel(), req, timeout: 30_000)

    response.org_ids
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
