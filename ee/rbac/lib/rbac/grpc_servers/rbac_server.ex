defmodule Rbac.GrpcServers.RbacServer do
  @moduledoc """
    Documentation for all of the endpoints can be found in the internal_api repo: https://github.com/renderedtext/internal_api/blob/master/rbac.proto
  """
  use GRPC.Server, service: InternalApi.RBAC.RBAC.Service

  require Logger
  import Rbac.Utils.Grpc, only: [validate_uuid!: 1, grpc_error!: 2]

  alias Rbac.RoleBindingIdentification, as: RBI
  alias InternalApi.RBAC

  def list_user_permissions(%RBAC.ListUserPermissionsRequest{} = req, _stream) do
    alias Rbac.Store.UserPermissions

    Watchman.benchmark("list_user_permissions.duration", fn ->
      [req.user_id, req.org_id] |> validate_uuid!()
      if req.project_id != "", do: validate_uuid!(req.project_id)

      {:ok, rbi} =
        RBI.new(
          user_id: req.user_id,
          org_id: req.org_id,
          project_id: if(req.project_id != "", do: req.project_id, else: :is_nil)
        )

      all_user_permissions =
        UserPermissions.read_user_permissions(rbi)
        |> String.split(",")
        |> Enum.filter(&(&1 != ""))

      %RBAC.ListUserPermissionsResponse{
        user_id: req.user_id,
        org_id: req.org_id,
        project_id: req.project_id,
        permissions: all_user_permissions
      }
    end)
  end

  def list_existing_permissions(%RBAC.ListExistingPermissionsRequest{scope: scope}, _stream) do
    Watchman.benchmark("list_existing_permissions.duration", fn ->
      scope_name = scope_grpc_enum_to_name(scope)
      permissions = Rbac.Repo.Permission.fetch_permissions(scope_name)

      %RBAC.ListExistingPermissionsResponse{
        permissions: Enum.map(permissions, &construct_grpc_permission/1)
      }
    end)
  end

  # ====================== MANAGE ROLES ASSIGNMENTS ====================== #
  def assign_role(%RBAC.AssignRoleRequest{} = req, _stream) do
    Watchman.benchmark("assign_role.duration", fn ->
      %{
        subject: %{subject_id: subject_id},
        org_id: org_id,
        project_id: project_id,
        role_id: role_id
      } = req.role_assignment

      validate_role_assignment_arguments(req.role_assignment)
      authorize!(req.requester_id, org_id, project_id)
      {:ok, rbi} = RBI.new(user_id: subject_id, org_id: org_id, project_id: project_id)

      case Rbac.RoleManagement.assign_role(rbi, role_id, :manually_assigned) do
        {:ok, nil} ->
          Rbac.Events.Authorization.publish("role_assigned", subject_id, org_id)
          %RBAC.AssignRoleResponse{}

        {:error, error_msg} ->
          Logger.error("Error assigning role: #{error_msg}")
          grpc_error!(:failed_precondition, error_msg)
      end
    end)
  end

  def retract_role(%RBAC.RetractRoleRequest{} = req, _stream) do
    Watchman.benchmark("retract_role.duration", fn ->
      %{subject: %{subject_id: subject_id}, org_id: org_id, project_id: project_id} =
        req.role_assignment

      [subject_id, org_id] |> validate_uuid!()
      if project_id != "", do: validate_uuid!(project_id)
      if project_id == "", do: raise_error_if_user_is_owner(subject_id, org_id)
      authorize!(req.requester_id, org_id, project_id)

      {:ok, rbi} =
        if project_id == "" do
          RBI.new(user_id: subject_id, org_id: org_id, project_id: :is_nil)
        else
          RBI.new(user_id: subject_id, org_id: org_id, project_id: project_id)
        end

      Rbac.RoleManagement.retract_roles(rbi, :manually_assigned)

      unless Rbac.RoleManagement.user_part_of_org?(subject_id, org_id) do
        Rbac.Store.Group.remove_member_from_all_org_groups(subject_id, org_id, req.requester_id)
        # Remove all project and org level roles, regardless of how they were assigned
        {:ok, rbi} = RBI.new(user_id: subject_id, org_id: org_id)
        Rbac.RoleManagement.retract_roles(rbi)
      end

      Rbac.Events.Authorization.publish("role_retracted", subject_id, org_id)
      %RBAC.RetractRoleResponse{}
    end)
  end

  # ====================================================================== #

  # ======================== CRUD ROLE OPERATIONS ======================== #
  def list_roles(%RBAC.ListRolesRequest{org_id: org_id, scope: scope}, _stream) do
    Watchman.benchmark("list_roles.duration", fn ->
      org_id |> validate_uuid!()

      scope_id = scope_grpc_enum_to_name(scope) |> Rbac.Repo.Scope.scope_name_to_id()
      roles = Rbac.Repo.RbacRole.list_roles(org_id, scope_id)

      if roles |> length() == 0 do
        Logger.error(
          "Organization with id #{org_id} has no roles! Scope id given in the request: #{scope_id}"
        )
      end

      %RBAC.ListRolesResponse{roles: Enum.map(roles, &construct_grpc_role(&1))}
    end)
  end

  def describe_role(%RBAC.DescribeRoleRequest{role_id: role_id, org_id: org_id}, _stream) do
    Watchman.benchmark("describe_role.duration", fn ->
      [role_id, org_id] |> validate_uuid!()

      case Rbac.Store.RbacRole.fetch(role_id, org_id) do
        {:ok, role} -> %RBAC.DescribeRoleResponse{role: construct_grpc_role(role)}
        {:error, _} -> grpc_error!(:not_found, "Role with id #{role_id} not found")
      end
    end)
  end

  @manage_roles_permission "organization.custom_roles.manage"
  def modify_role(%RBAC.ModifyRoleRequest{role: role, requester_id: requester_id}, _stream) do
    Watchman.benchmark("modify_role.duration", fn ->
      [role.org_id, requester_id] |> validate_uuid!()
      Rbac.Utils.Grpc.authorize!(@manage_roles_permission, requester_id, role.org_id)

      case Rbac.Store.RbacRole.create_or_update(from_api_to_params(role)) do
        {:ok, role} -> %RBAC.ModifyRoleResponse{role: construct_grpc_role(role)}
        {:error, message} -> grpc_error!(:invalid_argument, message)
      end
    end)
  end

  def destroy_role(%RBAC.DestroyRoleRequest{} = req, _) do
    [req.org_id, req.role_id, req.requester_id] |> validate_uuid!()
    Rbac.Utils.Grpc.authorize!(@manage_roles_permission, req.requester_id, req.org_id)

    case Rbac.Store.RbacRole.delete_role(req.role_id, req.org_id) do
      {:ok, role} -> %RBAC.DestroyRoleResponse{role_id: role.id}
      {:error, message} -> grpc_error!(:failed_precondition, message)
    end
  end

  # ====================================================================== #

  def list_members(%RBAC.ListMembersRequest{} = req, _stream) do
    Watchman.benchmark("list_members.duration", fn ->
      validate_uuid!(req.org_id)
      if req.project_id != "", do: validate_uuid!(req.project_id)

      project_id = if req.project_id != "", do: req.project_id, else: :is_nil
      {:ok, rbi} = RBI.new(org_id: req.org_id, project_id: project_id)
      page = if is_nil(req.page), do: %{page_no: 0, page_size: 0}, else: req.page
      member_type = req.member_type |> Atom.to_string() |> String.downcase()

      {subject_role_bindings, total_pages} =
        Rbac.RoleManagement.fetch_subject_role_bindings(
          rbi,
          page_no: page.page_no,
          page_size: page.page_size,
          subject_name: req.member_name_contains,
          subject_type: member_type,
          role_id: req.member_has_role
        )

      construct_grpc_members(subject_role_bindings, total_pages)
    end)
  end

  def count_members(%RBAC.CountMembersRequest{org_id: org_id}, _stream) do
    Watchman.benchmark("count_members.duration", fn ->
      validate_uuid!(org_id)

      {:ok, rbi} = RBI.new(org_id: org_id)
      count = Rbac.RoleManagement.count_subject_role_bindings(rbi)

      if count > 0 do
        %RBAC.CountMembersResponse{members: count}
      else
        grpc_error!(:not_found, "Organization not found for id #{org_id}")
      end
    end)
  end

  def subjects_have_roles(%RBAC.SubjectsHaveRolesRequest{role_assignments: assignments}, _stream) do
    Watchman.benchmark("subjects_have_roles.duration", fn ->
      has_roles =
        Enum.map(assignments, fn assignment ->
          validate_subjects_have_roles_arguments(assignment)

          {:ok, rbi} =
            RBI.new(
              user_id: assignment.subject.subject_id,
              org_id: assignment.org_id,
              project_id:
                if(assignment.project_id == "", do: :is_nil, else: assignment.project_id)
            )

          %RBAC.SubjectsHaveRolesResponse.HasRole{
            role_assignment: assignment,
            has_role: Rbac.RoleManagement.has_role(rbi, assignment.role_id)
          }
        end)

      %RBAC.SubjectsHaveRolesResponse{has_roles: has_roles}
    end)
  end

  @first_page 0
  @page_size 40
  def list_accessible_orgs(%RBAC.ListAccessibleOrgsRequest{user_id: user_id}, _stream) do
    Watchman.benchmark("list_accessible_orgs.duration", fn ->
      validate_uuid!(user_id)
      {:ok, rbi} = RBI.new(user_id: user_id, project_id: :is_nil)

      {org_role_bindings, _total_pages} =
        Rbac.RoleManagement.fetch_subject_role_bindings(rbi,
          page_no: @first_page,
          page_size: @page_size
        )

      org_ids = org_role_bindings |> Enum.map(& &1.org_id) |> Enum.uniq()

      %RBAC.ListAccessibleOrgsResponse{org_ids: org_ids}
    end)
  end

  def list_accessible_projects(
        %RBAC.ListAccessibleProjectsRequest{user_id: user_id, org_id: org_id},
        _stream
      ) do
    Watchman.benchmark("list_accessible_projects.duration", fn ->
      [org_id, user_id] |> validate_uuid!()
      project_ids = Rbac.Store.ProjectAccess.get_list_of_projects(user_id, org_id)
      %RBAC.ListAccessibleProjectsResponse{project_ids: project_ids}
    end)
  end

  def refresh_collaborators(%RBAC.RefreshCollaboratorsRequest{org_id: org_id}, _stream) do
    Watchman.benchmark("refresh_collaborators.duration", fn ->
      validate_uuid!(org_id)

      Rbac.Refresh.Organization.refresh([org_id])
      %RBAC.RefreshCollaboratorsResponse{}
    end)
  end

  ###
  ### Helper functions
  ###

  @manage_global_roles "insider.global_roles.manage"
  @manage_org_roles "organization.people.manage"
  @manage_project_roles "project.access.manage"
  defp authorize!(user_id, org_id, project_id) do
    import Rbac.Utils.Common, only: [nil_uuid: 0]
    import Rbac.Utils.Grpc, only: [authorize!: 4]

    cond do
      org_id == nil_uuid() -> authorize!(@manage_global_roles, user_id, org_id, "")
      project_id == "" -> authorize!(@manage_org_roles, user_id, org_id, "")
      Rbac.Models.Project.project_being_initialized?(project_id) -> nil
      true -> authorize!(@manage_project_roles, user_id, org_id, project_id)
    end
  end

  defp raise_error_if_user_is_owner(user_id, org_id) do
    {:ok, rbi} = RBI.new(user_id: user_id, org_id: org_id, project_id: :is_nil)

    is_owner? =
      Rbac.RoleManagement.fetch_subject_role_bindings(rbi)
      |> elem(0)
      |> List.first(%{})
      |> Map.get(:role_bindings, [])
      |> Enum.map(&Rbac.Repo.RbacRole.get_role_by_id(&1["role_id"]))
      |> Enum.any?(&(&1.name == "Owner"))

    if is_owner?, do: grpc_error!(:invalid_argument, "Owner can not be removed")
  end

  defp validate_subjects_have_roles_arguments(%{
         role_id: role_id,
         subject: %{subject_id: subject_id},
         org_id: org_id,
         project_id: project_id
       }) do
    [subject_id, org_id, role_id] |> validate_uuid!()
    if project_id != "", do: validate_uuid!(project_id)
  end

  defp validate_role_assignment_arguments(arg) do
    %{
      role_id: role_id,
      subject: %{subject_id: subject_id},
      org_id: org_id,
      project_id: project_id
    } = arg

    validate_uuid!([role_id, subject_id, org_id])
    role = role_id |> Rbac.Repo.RbacRole.get_role_by_id()

    if role == nil,
      do: grpc_error!(:failed_precondition, "Role with id #{role_id} does not exist.")

    case role.scope.scope_name do
      "project_scope" ->
        validate_project!(project_id, org_id)

      # If role is org level, or insider level, project id must not be supplied in the request
      scope when scope in ["org_scope", "insider_scope"] ->
        if project_id != "",
          do:
            grpc_error!(
              :failed_precondition,
              "You are trying to assign an org level role, but supplied a project_id with request."
            )

      true ->
        grpc_error!(:failed_precondition, "Unrecognized scope #{role.scope.scope_name}")
    end

    if role.org_id != org_id,
      do:
        grpc_error!(
          :failed_precondition,
          "Role you are trying to assign must belong to the org given in the request."
        )
  end

  defp validate_project!(project_id, org_id) do
    validate_uuid!(project_id)

    project =
      case Rbac.Models.Project.find(project_id) do
        {:error, :project_not_found} ->
          grpc_error!(:failed_precondition, "Project does not exist #{project_id}")

        {:ok, project} ->
          project
      end

    if project.org_id != org_id,
      do: grpc_error!(:failed_precondition, "Project does not belong to the organization")
  end

  ###
  ### Construct GRCP responses
  ###

  defp construct_grpc_members(subject_role_bindings, total_pages) do
    %RBAC.ListMembersResponse{
      total_pages: total_pages,
      members:
        Enum.map(subject_role_bindings, fn binding ->
          subject_type = binding.type |> String.upcase() |> String.to_existing_atom()

          %RBAC.ListMembersResponse.Member{
            subject: %RBAC.Subject{
              subject_type: subject_type,
              subject_id: binding.subject_id,
              display_name: binding.name
            },
            subject_role_bindings:
              Enum.map(binding.role_bindings, fn role_binding ->
                construct_grpc_subject_role_binding(role_binding)
              end)
              |> Enum.sort_by(& &1.role.name)
          }
        end)
        |> Enum.sort_by(& &1.subject.display_name)
    }
  end

  defp construct_grpc_subject_role_binding(binding) do
    role = Rbac.Repo.RbacRole.get_role_by_id(binding["role_id"])

    %RBAC.SubjectRoleBinding{
      role: construct_grpc_role(role),
      role_assigned_at: %Google.Protobuf.Timestamp{
        seconds:
          binding["inserted_at"]
          |> NaiveDateTime.from_iso8601!()
          |> DateTime.from_naive!("Etc/UTC")
          |> DateTime.to_unix()
      },
      source:
        case binding["binding_source"] do
          "manually_assigned" -> :ROLE_BINDING_SOURCE_MANUALLY
          "github" -> :ROLE_BINDING_SOURCE_GITHUB
          "bitbucket" -> :ROLE_BINDING_SOURCE_BITBUCKET
          "okta" -> :ROLE_BINDING_SOURCE_SCIM
          "inherited_from_org_role" -> :ROLE_BINDING_SOURCE_INHERITED_FROM_ORG_ROLE
          _ -> :ROLE_BINDING_SOURCE_UNSPECIFIED
        end
    }
  end

  defp construct_grpc_role(nil), do: nil
  defp construct_grpc_role(%Ecto.Association.NotLoaded{}), do: nil

  defp construct_grpc_role(role) do
    permissions = Enum.map(role.permissions, &%{&1 | scope: role.scope})

    %RBAC.Role{
      id: role.id,
      name: role.name,
      org_id: role.org_id,
      description: role.description,
      permissions: Enum.map(permissions, & &1.name),
      rbac_permissions: Enum.map(permissions, &construct_grpc_permission/1),
      scope: scope_name_to_grpc_enum(role.scope.scope_name),
      maps_to: construct_grpc_role(role.proj_role_mapping),
      inherited_role: construct_grpc_role(role.inherited_role),
      readonly: !role.editable
    }
  end

  defp construct_grpc_permission(permission) do
    %RBAC.Permission{
      id: permission.id,
      name: permission.name,
      description: permission.description,
      scope: scope_name_to_grpc_enum(permission.scope.scope_name)
    }
  end

  defp scope_name_to_grpc_enum(name) do
    case name do
      "org_scope" -> :SCOPE_ORG
      "project_scope" -> :SCOPE_PROJECT
      _ -> :SCOPE_UNSPECIFIED
    end
  end

  defp scope_grpc_enum_to_name(enum) do
    case enum do
      :SCOPE_ORG -> "org_scope"
      :SCOPE_PROJECT -> "project_scope"
      _ -> nil
    end
  end

  defp from_api_to_params(%RBAC.Role{} = role) do
    inherited_role_id = if role.inherited_role != nil, do: role.inherited_role.id, else: nil
    maps_to_role_id = if role.maps_to != nil, do: role.maps_to.id, else: nil
    scope_id = scope_grpc_enum_to_name(role.scope) |> Rbac.Repo.Scope.scope_name_to_id()

    role
    |> Map.from_struct()
    |> Enum.into([])
    |> Keyword.take([:id, :name, :description, :org_id])
    |> Keyword.put(:permission_ids, Enum.map(role.rbac_permissions, & &1.id))
    |> Keyword.put(:inherited_role_id, inherited_role_id)
    |> Keyword.put(:maps_to_role_id, maps_to_role_id)
    |> Keyword.put(:scope_id, scope_id)
  end
end
