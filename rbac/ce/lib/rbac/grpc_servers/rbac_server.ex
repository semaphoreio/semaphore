defmodule Rbac.GrpcServers.RbacServer do
  use GRPC.Server, service: InternalApi.RBAC.RBAC.Service
  require Logger

  alias InternalApi.RBAC
  alias Rbac.Utils.Log
  alias Rbac.Models.{RoleAssignment, ProjectAssignment}

  import Rbac.Utils.Grpc, only: [grpc_error!: 2, validate_uuid!: 1, valid_uuid?: 1]

  @default_page_size 20
  @default_page_no 1

  @spec list_roles(RBAC.ListRolesRequest.t(), GRPC.Server.Stream.t()) ::
          RBAC.ListRolesResponse.t()
  def list_roles(%RBAC.ListRolesRequest{scope: scope}, _stream) do
    Log.observe("grpc.rbac.list_roles", fn ->
      roles = if scope == :SCOPE_PROJECT, do: [], else: Rbac.Roles.build_grpc_roles()

      %RBAC.ListRolesResponse{roles: roles}
    end)
  end

  @spec list_existing_permissions(RBAC.ListExistingPermissionsRequest.t(), GRPC.Server.Stream.t()) ::
          RBAC.ListExistingPermissionsResponse.t()
  def list_existing_permissions(%RBAC.ListExistingPermissionsRequest{scope: scope}, _stream) do
    Log.observe("grpc.rbac.list_existing_permissions", fn ->
      permissions =
        case scope do
          :SCOPE_ORG ->
            Rbac.Permissions.list_organization_permissions()

          :SCOPE_PROJECT ->
            Rbac.Permissions.list_project_permissions()

          _ ->
            Rbac.Permissions.list()
        end

      %RBAC.ListExistingPermissionsResponse{
        permissions: permissions |> Enum.map(&Rbac.Permissions.construct_grpc_permission/1)
      }
    end)
  end

  @spec assign_role(RBAC.AssignRoleRequest.t(), GRPC.Server.Stream.t()) ::
          RBAC.AssignRoleResponse.t()
  def assign_role(
        %RBAC.AssignRoleRequest{role_assignment: role_assignment} = request,
        _stream
      ) do
    Log.observe("grpc.rbac.assign_role", fn ->
      validate_role_assignment_request!(request)

      org_id = role_assignment.org_id
      role_id = role_assignment.role_id
      project_id = role_assignment.project_id
      subject_id = role_assignment.subject.subject_id
      subject_type = role_assignment.subject.subject_type

      cond do
        valid_uuid?(role_id) ->
          handle_role_assignment(org_id, subject_id, role_id, subject_type)

        valid_uuid?(project_id) ->
          handle_project_assignment(subject_id, org_id, project_id)

        true ->
          grpc_error!(:invalid_argument, "Role ID or Project ID must be provided")
      end

      Rbac.Events.publish("role_assigned", subject_id, org_id, project_id)

      %RBAC.AssignRoleResponse{}
    end)
  end

  @spec list_user_permissions(RBAC.ListUserPermissionsRequest.t(), GRPC.Server.Stream.t()) ::
          RBAC.ListUserPermissionsResponse.t()
  def list_user_permissions(
        %RBAC.ListUserPermissionsRequest{
          user_id: user_id,
          org_id: org_id,
          project_id: project_id
        },
        _stream
      ) do
    Log.observe("grpc.rbac.list_user_permissions", fn ->
      validate_uuid!([org_id, user_id])

      role_assignment = RoleAssignment.get_by_user_and_org_id(user_id, org_id)

      cond do
        is_nil(role_assignment) ->
          build_list_premissions_resp(user_id, org_id, nil, project_id)

        valid_uuid?(project_id) ->
          handle_list_user_permissions_on_project(user_id, org_id, project_id, role_assignment)

        project_id == "" ->
          role = Rbac.Roles.find_by_id(role_assignment.role_id)
          build_list_premissions_resp(user_id, org_id, role)

        true ->
          grpc_error!(:invalid_argument, "Project id #{project_id} is not a valid UUID")
      end
    end)
  end

  @spec list_accessible_orgs(RBAC.ListAccessibleOrgsRequest.t(), GRPC.Server.Stream.t()) ::
          RBAC.ListAccessibleOrgsResponse.t()
  def list_accessible_orgs(%RBAC.ListAccessibleOrgsRequest{user_id: user_id}, _stream) do
    Log.observe("grpc.rbac.list_accessible_orgs", fn ->
      validate_uuid!(user_id)

      org_ids = Rbac.Models.RoleAssignment.get_org_ids_by_user_id(user_id)
      %RBAC.ListAccessibleOrgsResponse{org_ids: org_ids}
    end)
  end

  @spec list_accessible_projects(RBAC.ListAccessibleProjectsRequest.t(), GRPC.Server.Stream.t()) ::
          RBAC.ListAccessibleProjectsResponse.t()
  def list_accessible_projects(
        %RBAC.ListAccessibleProjectsRequest{user_id: user_id, org_id: org_id},
        _stream
      ) do
    Log.observe("grpc.rbac.list_accessible_projects", fn ->
      validate_uuid!([user_id, org_id])

      project_ids =
        case RoleAssignment.get_by_user_and_org_id(user_id, org_id) do
          %RoleAssignment{role_id: role_id} ->
            if role_id == Rbac.Roles.Member.role().id do
              Rbac.Models.ProjectAssignment.get_project_ids_by_user_id_and_org_id(user_id, org_id)
            else
              handle_get_all_projects(org_id)
            end

          _ ->
            []
        end

      %RBAC.ListAccessibleProjectsResponse{project_ids: project_ids}
    end)
  end

  @spec retract_role(RBAC.RetractRoleRequest.t(), GRPC.Server.Stream.t()) ::
          RBAC.RetractRoleResponse.t()
  def retract_role(%RBAC.RetractRoleRequest{role_assignment: role_assignment} = request, _stream) do
    Log.observe("grpc.rbac.retract_role", fn ->
      validate_role_assignment_request!(request)

      org_id = role_assignment.org_id
      role_id = role_assignment.role_id
      project_id = role_assignment.project_id
      subject_id = role_assignment.subject.subject_id

      cond do
        valid_uuid?(role_id) ->
          handle_retract_role(org_id, subject_id, role_id)

        valid_uuid?(project_id) ->
          handle_retract_project_assignment(subject_id, org_id, project_id)

        true ->
          handle_delete_role_assignment(org_id, subject_id)
      end

      Rbac.Events.publish("role_retracted", subject_id, org_id, project_id)

      %RBAC.RetractRoleResponse{}
    end)
  end

  @spec list_members(RBAC.ListMembersRequest.t(), GRPC.Server.Stream.t()) ::
          RBAC.ListMembersResponse.t()
  def list_members(%RBAC.ListMembersRequest{member_type: :GROUP}, _stream) do
    %RBAC.ListMembersResponse{
      members: [],
      total_pages: 0
    }
  end

  @spec list_members(RBAC.ListMembersRequest.t(), GRPC.Server.Stream.t()) ::
          RBAC.ListMembersResponse.t()
  def list_members(%RBAC.ListMembersRequest{page: page} = request, _stream) do
    Log.observe("grpc.rbac.list_members", fn ->
      validate_uuid!(request.org_id)
      search_params = build_search_params(request, page)

      %{results: role_assignments, total_count: total_count} =
        RoleAssignment.search(search_params)

      display_names_by_id = fetch_display_names(role_assignments)

      %RBAC.ListMembersResponse{
        members: build_members_response(role_assignments, display_names_by_id),
        total_pages: calculate_total_pages(total_count, search_params[:page_size])
      }
    end)
  end

  @spec count_members(RBAC.CountMembersRequest.t(), GRPC.Server.Stream.t()) ::
          RBAC.CountMembersResponse.t()
  def count_members(%RBAC.CountMembersRequest{org_id: org_id}, _stream) do
    Log.observe("grpc.rbac.count_members", fn ->
      validate_uuid!(org_id)

      count = RoleAssignment.count_by_org_id(org_id)

      if count > 0 do
        %RBAC.CountMembersResponse{members: count}
      else
        grpc_error!(:not_found, "Organization with id #{org_id} not found")
      end
    end)
  end

  @spec subjects_have_roles(RBAC.SubjectsHaveRolesRequest.t(), GRPC.Server.Stream.t()) ::
          RBAC.SubjectsHaveRolesResponse.t()
  def subjects_have_roles(
        %RBAC.SubjectsHaveRolesRequest{},
        _stream
      ) do
    Log.observe("grpc.rbac.subjects_have_roles", fn ->
      grpc_error!(:unimplemented, "SubjectsHaveRoles is not implemented")
    end)
  end

  @spec describe_role(RBAC.DescribeRoleRequest.t(), GRPC.Server.Stream.t()) ::
          RBAC.DescribeRoleResponse.t()
  def describe_role(%RBAC.DescribeRoleRequest{role_id: role_id}, _stream) do
    Log.observe("grpc.rbac.describe_role", fn ->
      validate_uuid!(role_id)

      role = Rbac.Roles.find_by_id(role_id)

      if is_nil(role) do
        grpc_error!(:not_found, "Role with id #{role_id} not found")
      end

      %RBAC.DescribeRoleResponse{
        role: Rbac.Roles.construct_grpc_role(role, assign_permissions: true)
      }
    end)
  end

  @spec destroy_role(RBAC.DestroyRoleRequest.t(), GRPC.Server.Stream.t()) ::
          RBAC.DestroyRoleResponse.t()
  def destroy_role(_request, _stream) do
    Log.observe("grpc.rbac.destroy_role", fn ->
      grpc_error!(:unimplemented, "Destroy role is not implemented")
    end)
  end

  @spec modify_role(RBAC.ModifyRoleRequest.t(), GRPC.Server.Stream.t()) ::
          RBAC.ModifyRoleResponse.t()
  def modify_role(_request, _stream) do
    Log.observe("grpc.rbac.modify_role", fn ->
      grpc_error!(:unimplemented, "Modify role is not implemented")
    end)
  end

  # ----------------
  # Helper functions
  # ----------------

  defp build_list_premissions_resp(user_id, org_id, role, project_id \\ "") do
    permissions =
      cond do
        role == nil ->
          []

        project_id != "" ->
          role.permissions |> Enum.filter(&Rbac.Permissions.project_permission?(&1))

        true ->
          role.permissions
      end

    %RBAC.ListUserPermissionsResponse{
      user_id: user_id,
      org_id: org_id,
      project_id: project_id,
      permissions: permissions
    }
  end

  defp handle_list_user_permissions_on_project(user_id, org_id, project_id, role_assignment) do
    member? = role_assignment.role_id == Rbac.Roles.Member.role().id
    project_access? = !is_nil(ProjectAssignment.get_by_user_and_project_id(user_id, project_id))

    role =
      if member? and !project_access?,
        do: nil,
        else: Rbac.Roles.find_by_id(role_assignment.role_id)

    build_list_premissions_resp(user_id, org_id, role, project_id)
  end

  defp build_search_params(request, page) do
    Logger.info("build_search_params: #{inspect(request)}")

    params =
      request
      |> Map.from_struct()
      |> Enum.reduce([], &accumulate_search_param(request.org_id, &1, &2))
      |> Keyword.merge(
        org_id: request.org_id,
        page_number: if(page.page_no > 0, do: page.page_no, else: @default_page_no),
        page_size: if(page.page_size > 0, do: page.page_size, else: @default_page_size)
      )

    if params[:user_ids] do
      Keyword.put(params, :user_ids, Enum.to_list(params[:user_ids]))
    else
      params
    end
  end

  defp accumulate_search_param(org_id, {key, value}, acc) do
    case key do
      :project_id ->
        if valid_uuid?(value) do
          # Owner and Admin should have access to all projects
          fetch_owner_and_admin_user_ids =
            Task.async(fn -> RoleAssignment.get_owner_and_admin_user_ids(org_id) end)

          fetch_project_member_user_ids =
            Task.async(fn -> ProjectAssignment.get_user_ids_by_org_project(org_id, value) end)

          user_ids =
            Task.await(fetch_owner_and_admin_user_ids) ++
              Task.await(fetch_project_member_user_ids)

          merge_user_ids(acc, MapSet.new(user_ids))
        else
          acc
        end

      :member_name_contains when value != "" ->
        user_ids = fetch_user_ids_by_name(value)
        merge_user_ids(acc, MapSet.new(user_ids))

      :member_has_role ->
        if valid_uuid?(value), do: Keyword.put(acc, :role_id, value), else: acc

      :member_type ->
        Keyword.put(acc, :subject_type, value |> Atom.to_string() |> String.downcase())

      _ ->
        acc
    end
  end

  defp fetch_user_ids_by_name(name) do
    case Rbac.Api.User.search(name) do
      {:ok, result} -> Enum.map(result.users, & &1.id)
      _ -> []
    end
  end

  defp merge_user_ids(acc, user_ids) do
    if acc[:user_ids] do
      Keyword.put(acc, :user_ids, MapSet.intersection(acc[:user_ids], user_ids))
    else
      Keyword.put(acc, :user_ids, user_ids)
    end
  end

  defp fetch_display_names(role_assignments) do
    user_ids = role_assignments |> Enum.map(& &1.user_id)

    case Rbac.Api.User.get_many(user_ids) do
      {:ok, result} ->
        Enum.reduce(result.users, %{}, fn user, acc -> Map.put(acc, user.id, user.name) end)

      _ ->
        %{}
    end
  end

  defp build_members_response(role_assignments, display_names_by_id) do
    Enum.map(role_assignments, fn assignment ->
      # Determine subject type - for CE, we support USER and SERVICE_ACCOUNT
      # We need to determine if this user_id is a service account
      subject_type = assignment.subject_type |> String.upcase() |> String.to_existing_atom()

      %RBAC.ListMembersResponse.Member{
        subject: %RBAC.Subject{
          subject_id: assignment.user_id,
          subject_type: subject_type,
          display_name: display_names_by_id[assignment.user_id] || ""
        },
        subject_role_bindings: [build_subject_role_binding(assignment)]
      }
    end)
  end

  defp build_subject_role_binding(assignment) do
    %RBAC.SubjectRoleBinding{
      role:
        Rbac.Roles.find_by_id(assignment.role_id)
        |> Rbac.Roles.construct_grpc_role(assign_permissions: true),
      source: :ROLE_BINDING_SOURCE_MANUALLY,
      role_assigned_at: build_role_assigned_timestamp()
    }
  end

  defp build_role_assigned_timestamp do
    DateTime.utc_now()
    |> DateTime.to_unix(:second)
    |> then(fn seconds -> %Google.Protobuf.Timestamp{seconds: seconds} end)
  end

  defp calculate_total_pages(total_count, page_size) do
    ceil(total_count / page_size)
  end

  defp handle_get_all_projects(org_id) do
    case Rbac.Api.Project.list_by_org_id(org_id) do
      {:ok, projects} ->
        projects
        |> Enum.map(fn project -> project.metadata.id end)

      {:error, message} ->
        grpc_error!(:internal, message)
    end
  end

  defp handle_retract_role(org_id, subject_id, role_id) do
    role = Rbac.Roles.find_by_id(role_id)

    if is_nil(role) do
      grpc_error!(:not_found, "Role with id #{role_id} not found")
    end

    case RoleAssignment.get_by_user_and_org_id(subject_id, org_id) do
      %RoleAssignment{} = role ->
        RoleAssignment.delete(role)

      _ ->
        grpc_error!(
          :permission_denied,
          "User #{subject_id} doesn't have access to the organization #{org_id}"
        )
    end
  end

  defp handle_retract_project_assignment(subject_id, org_id, project_id) do
    case RoleAssignment.get_by_user_and_org_id(subject_id, org_id) do
      %RoleAssignment{} ->
        :ok

      _ ->
        grpc_error!(
          :permission_denied,
          "User #{subject_id} doesn't have access to the organization #{org_id}"
        )
    end

    case ProjectAssignment.get_by_user_and_project_id(subject_id, project_id) do
      %ProjectAssignment{} = project_assignment ->
        ProjectAssignment.delete(project_assignment)

      _ ->
        :ok
    end
  end

  defp handle_role_assignment(org_id, subject_id, role_id, subject_type) do
    role = Rbac.Roles.find_by_id(role_id)

    if is_nil(role) do
      grpc_error!(:not_found, "Role with id #{role_id} not found")
    end

    subject_type_string = convert_subject_type_to_string(subject_type)

    RoleAssignment.create_or_update(%{
      org_id: org_id,
      user_id: subject_id,
      role_id: role_id,
      subject_type: subject_type_string
    })
  end

  defp handle_delete_role_assignment(org_id, subject_id) do
    RoleAssignment.delete_by_org_and_user_id(org_id, subject_id)
  end

  defp handle_project_assignment(subject_id, org_id, project_id) do
    case RoleAssignment.get_by_user_and_org_id(subject_id, org_id) do
      %RoleAssignment{role_id: role_id} ->
        if role_id == Rbac.Roles.Member.role().id do
          project_assignment =
            ProjectAssignment.get_by_user_and_project_id(subject_id, project_id)

          if is_nil(project_assignment) do
            ProjectAssignment.create(%{
              org_id: org_id,
              project_id: project_id,
              user_id: subject_id
            })
          end
        end

        :ok

      _ ->
        :ok
    end
  end

  defp validate_role_assignment_request!(%{
         requester_id: requester_id,
         role_assignment: role_assignment
       }) do
    validate_uuid!(requester_id)

    if is_nil(role_assignment) do
      grpc_error!(:invalid_argument, "Role Assignment cannot be null")
    end

    if is_nil(role_assignment.subject) do
      grpc_error!(:invalid_argument, "Subject cannot be null")
    end

    validate_uuid!(role_assignment.org_id)
    validate_uuid!(role_assignment.subject.subject_id)
  end

  defp convert_subject_type_to_string(subject_type) do
    case subject_type do
      :USER -> "user"
      :SERVICE_ACCOUNT -> "service_account"
      :GROUP -> "group"
      # Default fallback for unknown values
      _ -> "user"
    end
  end
end
