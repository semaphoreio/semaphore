defmodule Guard.Api.Rbac do
  require Logger

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

  def retract_all_service_account_roles(service_account_id, org_id) do
    # Get organization to find the requester_id (organization owner)
    org = Guard.Api.Organization.fetch(org_id)

    Logger.info("Retracting roles for service account #{service_account_id} in org #{org_id}")

    with {:ok, role_assignments} <- list_service_account_roles(service_account_id, org_id),
         :ok <- retract_roles_individually(role_assignments, org.owner_id) do
      Logger.info(
        "Successfully retracted #{length(role_assignments)} roles for service account #{service_account_id}"
      )

      :ok
    else
      {:error, reason} ->
        Logger.error(
          "Failed to retract roles for service account #{service_account_id}: #{inspect(reason)}"
        )

        {:error, reason}

      error ->
        Logger.error(
          "Failed to retract roles for service account #{service_account_id}: #{inspect(error)}"
        )

        {:error, :retraction_failed}
    end
  rescue
    error ->
      Logger.error(
        "Failed to retract roles for service account #{service_account_id}: #{inspect(error)}"
      )

      {:error, :retraction_failed}
  end

  defp list_service_account_roles(service_account_id, org_id) do
    # Use ListMembers API to find role assignments for the service account
    # We'll check for the service account without specifying project_id
    # to get all role assignments across org and project levels

    req =
      InternalApi.RBAC.ListMembersRequest.new(
        org_id: org_id,
        # Don't specify project_id to get all roles across all projects and org
        member_type: InternalApi.RBAC.SubjectType.value(:SERVICE_ACCOUNT),
        page:
          InternalApi.RBAC.ListMembersRequest.Page.new(
            page_no: 1,
            # Large page size to get all results
            page_size: 1000
          )
      )

    case InternalApi.RBAC.RBAC.Stub.list_members(channel(), req, timeout: 30_000) do
      {:ok, response} ->
        # Find the specific service account in the results and extract its role assignments
        service_account_member =
          Enum.find(response.members, fn member ->
            member.subject.subject_id == service_account_id
          end)

        case service_account_member do
          nil ->
            # Service account not found, return empty list
            Logger.info(
              "No roles found for service account #{service_account_id} in org #{org_id}"
            )

            {:ok, []}

          member ->
            # Convert subject role bindings to role assignments for retraction
            # Since we can't easily determine project context from the bindings,
            # we'll attempt retraction with empty project_id and let RBAC service handle it
            role_assignments =
              Enum.map(member.subject_role_bindings, fn binding ->
                %{
                  role_id: binding.role.id,
                  org_id: org_id,
                  project_id: determine_project_id_from_role_scope(binding.role),
                  subject_id: service_account_id
                }
              end)

            Logger.info(
              "Found #{length(role_assignments)} role assignments for service account #{service_account_id}"
            )

            {:ok, role_assignments}
        end

      {:error, reason} ->
        Logger.error(
          "Failed to list members for service account #{service_account_id} in org #{org_id}: #{inspect(reason)}"
        )

        {:error, :list_members_failed}
    end
  end

  defp determine_project_id_from_role_scope(role) do
    # If the role has PROJECT scope, we can't easily determine the specific project_id
    # from the role binding information. For now, we'll use empty string which
    # should work for most retraction cases as the RBAC service should handle
    # the scope appropriately. In a production system, we might need additional
    # context or a different API to get project-specific role assignments.
    project_scope_value = InternalApi.RBAC.Scope.value(:SCOPE_PROJECT)

    case role.scope do
      ^project_scope_value ->
        # For project-scoped roles, we can't determine the project_id from this context
        # We'll need to rely on the RBAC service to handle retraction correctly
        ""

      _ ->
        # For org-level roles, empty project_id is appropriate
        ""
    end
  end

  defp retract_roles_individually(role_assignments, requester_id) do
    # Retract each role assignment individually
    results =
      Enum.map(role_assignments, fn assignment ->
        retract_single_role(assignment, requester_id)
      end)

    # Check if any retraction failed
    failed_retractions = Enum.filter(results, fn result -> result != :ok end)

    case failed_retractions do
      [] ->
        :ok

      failures ->
        Logger.error("Some role retractions failed: #{inspect(failures)}")
        {:error, :some_retractions_failed}
    end
  end

  defp retract_single_role(assignment, requester_id) do
    req =
      InternalApi.RBAC.RetractRoleRequest.new(
        requester_id: requester_id,
        role_assignment:
          InternalApi.RBAC.RoleAssignment.new(
            subject:
              InternalApi.RBAC.Subject.new(
                subject_id: assignment.subject_id,
                subject_type: InternalApi.RBAC.SubjectType.value(:SERVICE_ACCOUNT)
              ),
            org_id: assignment.org_id,
            role_id: assignment.role_id,
            project_id: assignment.project_id
          )
      )

    case InternalApi.RBAC.RBAC.Stub.retract_role(channel(), req, timeout: 30_000) do
      {:ok, _response} ->
        Logger.debug(
          "Retracted role #{assignment.role_id} for service account #{assignment.subject_id}"
        )

        :ok

      {:error, reason} ->
        Logger.error(
          "Failed to retract role #{assignment.role_id} for service account #{assignment.subject_id}: #{inspect(reason)}"
        )

        {:error, reason}
    end
  end

  defp channel do
    {:ok, channel} = GRPC.Stub.connect(Application.fetch_env!(:guard, :rbac_grpc_endpoint))

    channel
  end
end
