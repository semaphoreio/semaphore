# credo:disable-for-this-file
defmodule Rbac.GrpcServers.RbacServer.Test do
  @moduledoc """
    Integration tests for RBAC endpoints. No internal modules or functions are mocked.
  """
  # These tests cant be async, as each GRPC call spawns a new process, and Ecto sandbox transactions
  # cant span multiple processes
  use Rbac.RepoCase, async: false

  import Mock
  import Ecto.Query
  alias Ecto.UUID
  alias InternalApi.RBAC.RBAC.Stub

  @store_backend Application.compile_env(:rbac, :key_value_store_backend)
  @user_permissions_store_name Application.compile_env(:rbac, :user_permissions_store_name)
  @project_access_store_name Application.compile_env(:rbac, :project_access_store_name)

  @user_name "Jane Doe"
  @user_id UUID.generate()
  @org_id UUID.generate()
  @project_id UUID.generate()
  @requester_id UUID.generate()
  @org_admin_permissions ["organization.general_settings.manage", "organization.view"]
  @proj_reader_permissions ["project.view"]

  setup state do
    Support.Factories.RbacUser.insert(@user_id, @user_name)
    Support.Projects.insert(project_id: @project_id, org_id: @org_id)

    Support.Rbac.create_org_roles(@org_id)
    Support.Rbac.create_project_roles(@org_id)

    if !(Atom.to_string(state.test) =~ "unauthorized"), do: give_all_permissions()

    {:ok, channel} = GRPC.Stub.connect("localhost:50051")
    {:ok, %{grpc_channel: channel}}
  end

  describe "list_user_permissions" do
    alias InternalApi.RBAC.ListUserPermissionsRequest, as: Request

    test "invalid UUIDs return error", state do
      reqs = [
        %Request{org_id: ""},
        %Request{org_id: "*"},
        %Request{org_id: "not-valid-uuid"},
        %Request{user_id: ""},
        %Request{user_id: "not-valid-uuid"},
        %Request{project_id: ""},
        %Request{project_id: "*"},
        %Request{project_id: "not-valid-uuid"}
      ]

      Enum.each(reqs, fn req ->
        {:error, grpc_error} = state.grpc_channel |> Stub.list_user_permissions(req)
        assert grpc_error.message =~ "Invalid uuid"
      end)
    end

    test "organization permissions are not returned for user without organization role",
         state do
      Support.Rbac.assign_org_role_by_name(@org_id, @user_id, "Admin")
      req = %Request{user_id: @user_id, org_id: UUID.generate()}

      {:ok, %{permissions: permissions}} = state.grpc_channel |> Stub.list_user_permissions(req)
      assert permissions == []
    end

    test "organization permissions are returned for user with organization role", state do
      Support.Rbac.assign_org_role_by_name(@org_id, @user_id, "Admin")

      req = %Request{user_id: @user_id, org_id: @org_id}
      {:ok, %{permissions: permissions}} = state.grpc_channel |> Stub.list_user_permissions(req)
      assert Enum.sort(permissions) == Enum.sort(@org_admin_permissions)
    end

    test "no permissions returned if cache lookup raises", state do
      with_mocks [
        {@store_backend, [:passthrough],
         [
           get: fn @user_permissions_store_name, _key -> raise "oops" end
         ]}
      ] do
        assert_no_permissions_returned(state.grpc_channel)
      end
    end

    test "no permissions returned if cache lookup returns error", state do
      with_mocks [
        {@store_backend, [:passthrough],
         [
           get: fn @user_permissions_store_name, _key -> {:error, "oops"} end
         ]}
      ] do
        assert_no_permissions_returned(state.grpc_channel)
      end
    end

    test "organization and project permissions are returned when user has organization and project role",
         state do
      Support.Rbac.assign_org_role_by_name(@org_id, @user_id, "Admin")
      Support.Rbac.assign_project_role_by_name(@org_id, @user_id, @project_id, "Reader")

      req = %Request{user_id: @user_id, org_id: @org_id, project_id: @project_id}
      {:ok, %{permissions: permissions}} = state.grpc_channel |> Stub.list_user_permissions(req)

      assert Enum.sort(permissions) ==
               Enum.sort(@org_admin_permissions ++ @proj_reader_permissions)
    end
  end

  # The following values have been taken from the Support.Rbac module used for initializing data for the tests
  @no_of_org_permissions 4
  @no_of_project_permissions 6
  describe "list_existing_permissions" do
    alias InternalApi.RBAC.ListExistingPermissionsRequest, as: Request

    test "when scope is not specified, return project and org permissions (not insider)", state do
      {:ok, scope} = Support.Factories.Scope.insert("insider")
      Support.Factories.Permission.insert(name: "insider.view", scope_id: scope.id)

      {:ok, resp} = state.grpc_channel |> Stub.list_existing_permissions(%Request{})

      org_permissions = Enum.filter(resp.permissions, &(&1.scope == :SCOPE_ORG))
      proj_permissions = Enum.filter(resp.permissions, &(&1.scope == :SCOPE_PROJECT))

      assert length(org_permissions) == @no_of_org_permissions
      assert length(proj_permissions) == @no_of_project_permissions
      # There are no other permissions except those which are project and org scoped
      assert length(resp.permissions) == length(org_permissions ++ proj_permissions)
    end

    test "when scope is specified", state do
      org_req = %Request{scope: :SCOPE_ORG}
      proj_req = %Request{scope: :SCOPE_PROJECT}

      {:ok, org_resp} = state.grpc_channel |> Stub.list_existing_permissions(org_req)
      {:ok, proj_resp} = state.grpc_channel |> Stub.list_existing_permissions(proj_req)

      assert length(org_resp.permissions) == @no_of_org_permissions
      assert length(proj_resp.permissions) == @no_of_project_permissions
    end
  end

  describe "assign_role" do
    test "role is not assigned if parameters are not valid UUIDs", state do
      reqs = [
        gen_assign_role_req("", UUID.generate(), UUID.generate()),
        gen_assign_role_req("*", UUID.generate(), UUID.generate()),
        gen_assign_role_req(@user_id, "", UUID.generate()),
        gen_assign_role_req(@user_id, "*", UUID.generate()),
        gen_assign_role_req(@user_id, UUID.generate(), ""),
        gen_assign_role_req(@user_id, UUID.generate(), "*")
      ]

      Enum.each(reqs, fn req ->
        {:error, err} = state.grpc_channel |> Stub.assign_role(req)
        assert err.status == GRPC.Status.invalid_argument()
        assert err.message =~ "Invalid uuid"
      end)
    end

    test "organization role is not assigned if it does not exist", state do
      role_id = UUID.generate()
      req = gen_assign_role_req(@user_id, role_id, @org_id)
      {:error, err} = state.grpc_channel |> Stub.assign_role(req)

      assert err.status == GRPC.Status.failed_precondition()
      assert err.message =~ "Role with id #{role_id} does not exist"
    end

    test "role is not assigned if it is not owned by organization", state do
      non_existant_org_id = UUID.generate()
      {:ok, role} = Rbac.Repo.RbacRole.get_role_by_name("Admin", "org_scope", @org_id)

      req = gen_assign_role_req(@user_id, role.id, non_existant_org_id)
      {:error, err} = state.grpc_channel |> Stub.assign_role(req)

      assert err.status == GRPC.Status.failed_precondition()

      assert err.message =~
               "Role you are trying to assign must belong to the org given in the request"
    end

    test "project role is not assigned if project does not exist", state do
      GrpcMock.stub(ProjecthubMock, :describe, fn _, _ ->
        Rbac.Utils.Grpc.grpc_error!(:not_found, "Project does not exist")
      end)

      {:ok, role} = Rbac.Repo.RbacRole.get_role_by_name("Reader", "project_scope", @org_id)
      non_existant_proj_id = UUID.generate()
      req = gen_assign_role_req(@user_id, role.id, @org_id, non_existant_proj_id)

      {:error, err} = state.grpc_channel |> Stub.assign_role(req)
      assert err.status == GRPC.Status.failed_precondition()
      assert err.message =~ "Project does not exist"
    end

    test "project role is not assigned if project does not belong to organization", state do
      project_id = UUID.generate()
      Support.Projects.insert(project_id: project_id)

      GrpcMock.stub(ProjecthubMock, :describe, fn _, _ ->
        %InternalApi.Projecthub.DescribeResponse{
          project: Support.Factories.project(id: project_id),
          metadata: %InternalApi.Projecthub.ResponseMeta{
            status: %InternalApi.Projecthub.ResponseMeta.Status{
              code: :OK
            }
          }
        }
      end)

      {:ok, role} = Rbac.Repo.RbacRole.get_role_by_name("Reader", "project_scope", @org_id)

      req = gen_assign_role_req(@user_id, role.id, @org_id, project_id)
      {:error, err} = state.grpc_channel |> Stub.assign_role(req)

      assert err.status == GRPC.Status.failed_precondition()
      assert err.message =~ "Project does not belong to the organization"
    end

    test "project role is not assigned if project ID is not a valid UUID", state do
      {:ok, role} = Rbac.Repo.RbacRole.get_role_by_name("Reader", "project_scope", @org_id)
      req = gen_assign_role_req(@user_id, role.id, @org_id)
      {:error, err_msg} = state.grpc_channel |> Stub.assign_role(req)

      assert err_msg.message =~ "Invalid uuid passed"
    end

    test "organization role is not assigned if project ID is also specified", state do
      {:ok, org_role} = Rbac.Repo.RbacRole.get_role_by_name("Admin", "org_scope", @org_id)
      req = gen_assign_role_req(@user_id, org_role.id, @org_id, @project_id)
      {:error, err} = state.grpc_channel |> Stub.assign_role(req)

      assert err.status == GRPC.Status.failed_precondition()

      assert err.message =~
               "You are trying to assign an org level role, but supplied a project_id with request"
    end

    test "organization role is assigned when no role binding exists yet", state do
      assert Rbac.Repo.SubjectRoleBinding |> Rbac.Repo.all() |> length() == 0

      {:ok, org_role} = Rbac.Repo.RbacRole.get_role_by_name("Admin", "org_scope", @org_id)
      req = gen_assign_role_req(@user_id, org_role.id, @org_id)
      {:ok, _} = state.grpc_channel |> Stub.assign_role(req)

      assert Rbac.Repo.aggregate(Rbac.Repo.SubjectRoleBinding, :count, :id) == 1

      assert Rbac.Repo.aggregate(
               Rbac.Repo.SubjectRoleBinding |> where([srb], srb.role_id == ^org_role.id),
               :count,
               :id
             ) == 1
    end

    test "organization role is assigned when role binding already exists", state do
      Support.Rbac.assign_org_role_by_name(@org_id, @user_id, "Admin")
      assert Rbac.Repo.SubjectRoleBinding |> Rbac.Repo.all() |> length() == 1

      {:ok, member_role} = Rbac.Repo.RbacRole.get_role_by_name("Member", "org_scope", @org_id)
      req = gen_assign_role_req(@user_id, member_role.id, @org_id)
      {:ok, _} = state.grpc_channel |> Stub.assign_role(req)

      assert Rbac.Repo.aggregate(Rbac.Repo.SubjectRoleBinding, :count, :id) == 1

      assert Rbac.Repo.aggregate(
               Rbac.Repo.SubjectRoleBinding |> where([srb], srb.role_id == ^member_role.id),
               :count,
               :id
             ) == 1
    end

    test "project role is not assigned if user is not organization member", state do
      register_project_api_response()

      {:ok, proj_role} = Rbac.Repo.RbacRole.get_role_by_name("Admin", "project_scope", @org_id)
      req = gen_assign_role_req(@user_id, proj_role.id, @org_id, @project_id)

      assert {:error, err} = state.grpc_channel |> Stub.assign_role(req)
      assert err.message =~ "cant be assigned to a user that isn't already organization member"
      assert err.status == GRPC.Status.failed_precondition()
    end

    test "When requester is not passed while initializing new project, dont authorize the request",
         state do
      alias Rbac.Store.ProjectAccess

      Support.Rbac.assign_org_role_by_name(@org_id, @user_id, "Admin")
      {:ok, proj_role} = Rbac.Repo.RbacRole.get_role_by_name("Admin", "project_scope", @org_id)
      register_project_api_response(:INITIALIZING)

      req =
        gen_assign_role_req(@user_id, proj_role.id, @org_id, @project_id)
        |> Map.replace(:requester_id, "")

      {:ok, _} = state.grpc_channel |> Stub.assign_role(req)
      assert ProjectAccess.get_list_of_projects(@user_id, @org_id) == [@project_id]
    end

    test "Assign a global role to an 'insider'", state do
      alias Rbac.Repo.RbacRole
      alias Rbac.Store.{UserPermissions, ProjectAccess}
      alias Support.Factories.OrgRoleToProjRoleMappings

      nil_uuid = Rbac.Utils.Common.nil_uuid()

      {:ok, rbi} = Rbac.RoleBindingIdentification.new(user_id: @user_id, org_id: @org_id)
      assert UserPermissions.read_user_permissions(rbi) == ""

      # Create a set of "global roles" (nil uuid marks the role 'global')
      Support.Rbac.create_org_roles(nil_uuid)
      Support.Rbac.create_project_roles(nil_uuid)

      {_, global_admin} = RbacRole.get_role_by_name("Admin", "org_scope", nil_uuid)
      {_, proj_admin} = RbacRole.get_role_by_name("Admin", "project_scope", nil_uuid)
      OrgRoleToProjRoleMappings.insert(org_role_id: global_admin.id, proj_role_id: proj_admin.id)

      # Assign global admin role
      req = gen_assign_role_req(@user_id, global_admin.id, nil_uuid)
      {:ok, _} = state.grpc_channel |> Stub.assign_role(req)

      # This user should have "Admin" permissions within any organization
      assert UserPermissions.read_user_permissions(rbi) =~ "organization.view"
      assert UserPermissions.read_user_permissions(rbi) =~ "organization.general_settings.manage"

      assert ProjectAccess.get_list_of_projects(@user_id, @org_id) == [@project_id]
    end

    ###
    ### Testing authorization
    ###

    test "User has org level permissions, but is unauthorized for project management", state do
      key = "user:#{@requester_id}_org:*_project:*"
      permission = "insider.global_roles.manage"
      %Rbac.Repo.UserPermissionsKeyValueStore{key: key, value: permission} |> Rbac.Repo.insert()

      register_project_api_response()
      {:ok, role} = Rbac.Repo.RbacRole.get_role_by_name("Reader", "project_scope", @org_id)
      req = gen_assign_role_req(@user_id, role.id, @org_id, @project_id)

      {:error, err} = state.grpc_channel |> Stub.assign_role(req)
      assert err.status == GRPC.Status.permission_denied()
      assert err.message =~ "User unauthorized"
    end

    test "The user has global permission to assign insider roles, but is unauthorized to assign roles for individual orgs",
         state do
      key = "user:#{@requester_id}_org:*_project:*"
      permission = "insider.global_roles.manage"

      %Rbac.Repo.UserPermissionsKeyValueStore{key: key, value: permission} |> Rbac.Repo.insert()

      {:ok, role} = Rbac.Repo.RbacRole.get_role_by_name("Member", "org_scope", @org_id)
      req = gen_assign_role_req(@user_id, role.id, @org_id, "")

      {:error, err} = state.grpc_channel |> Stub.assign_role(req)
      assert err.status == GRPC.Status.permission_denied()
      assert err.message =~ "User unauthorized"
    end

    test "The user has global permission to assign org roles, but is unauthorized to assign insider roles",
         state do
      nil_uuid = Rbac.Utils.Common.nil_uuid()
      key = "user:#{@requester_id}_org:#{@org_id}_project:*"
      permission = "organization.people.manage,project.access.manage"

      %Rbac.Repo.UserPermissionsKeyValueStore{key: key, value: permission} |> Rbac.Repo.insert()

      # Inserting "insider" roles
      Support.Rbac.create_org_roles(nil_uuid)

      {:ok, role} = Rbac.Repo.RbacRole.get_role_by_name("Member", "org_scope", nil_uuid)
      req = gen_assign_role_req(@user_id, role.id, nil_uuid, "")

      {:error, err} = state.grpc_channel |> Stub.assign_role(req)
      assert err.status == GRPC.Status.permission_denied()
      assert err.message =~ "User unauthorized"
    end
  end

  describe "retract_role" do
    test "invalid data", state do
      req = gen_retract_role_req("", "")

      {:error, err} = state.grpc_channel |> Stub.retract_role(req)
      assert err.status == GRPC.Status.invalid_argument()
    end

    test "If same role is assigned twice, remove only the one that is 'manually_assigned'",
         state do
      Support.Rbac.assign_org_role_by_name(@org_id, @user_id, "Admin")
      Support.Rbac.assign_org_role_by_name(@org_id, @user_id, "Admin", :okta)
      Support.Rbac.assign_project_role_by_name(@org_id, @user_id, @project_id, "Reader")

      assert Rbac.Repo.aggregate(Rbac.Repo.SubjectRoleBinding, :count, :id) == 3

      req = gen_retract_role_req(@user_id, @org_id)
      {:ok, _} = state.grpc_channel |> Stub.retract_role(req)

      assert Rbac.Repo.aggregate(Rbac.Repo.SubjectRoleBinding, :count, :id) == 2

      assert Rbac.Repo.SubjectRoleBinding
             |> where([srb], is_nil(srb.project_id))
             |> Rbac.Repo.one()
             |> Map.get(:binding_source) ==
               :okta
    end

    test "If the only org role is being revoked, all the project roles should be revoked as well, and group memberships removed'",
         state do
      {:ok, worker} = Rbac.Workers.GroupManagement.start_link()
      on_exit(fn -> Process.exit(worker, :kill) end)

      Support.Rbac.assign_org_role_by_name(@org_id, @user_id, "Admin")
      Support.Rbac.assign_project_role_by_name(@org_id, @user_id, @project_id, "Reader")
      Support.Rbac.assign_project_role_by_name(@org_id, @user_id, @project_id, "Admin", :github)

      # Assign user to a group
      {:ok, group} = Support.Factories.Group.insert(org_id: @org_id)
      Support.Rbac.assign_org_role_by_name(@org_id, group.id, "Member")
      Support.Factories.UserGroupBinding.insert(group_id: group.id, user_id: @user_id)

      # Role within some other organization
      other_org = UUID.generate()
      Support.Rbac.create_org_roles(other_org)
      Support.Rbac.assign_org_role_by_name(other_org, @user_id, "Admin")

      req = gen_retract_role_req(@user_id, @org_id)
      {:ok, _} = state.grpc_channel |> Stub.retract_role(req)

      assert Rbac.Repo.aggregate(Rbac.Repo.SubjectRoleBinding, :count, :id) == 2

      :timer.sleep(3_000)

      {:ok, rbi} = Rbac.RoleBindingIdentification.new(user_id: @user_id, org_id: @org_id)
      assert Rbac.Store.UserPermissions.read_user_permissions(rbi) == ""
    end

    test "If one of two org role is being revoked, all the project roles should stay'",
         state do
      Support.Rbac.assign_org_role_by_name(@org_id, @user_id, "Admin")
      Support.Rbac.assign_org_role_by_name(@org_id, @user_id, "Member", :okta)
      Support.Rbac.assign_project_role_by_name(@org_id, @user_id, @project_id, "Admin", :github)

      req = gen_retract_role_req(@user_id, @org_id)
      {:ok, _} = state.grpc_channel |> Stub.retract_role(req)

      assert Rbac.Repo.aggregate(
               Rbac.Repo.SubjectRoleBinding |> where([srb], srb.org_id == ^@org_id),
               :count,
               :id
             ) == 2
    end

    test "If the user is Owner, raise an error", state do
      Support.Rbac.assign_org_role_by_name(@org_id, @user_id, "Owner")

      req = gen_retract_role_req(@user_id, @org_id)
      {:error, err} = state.grpc_channel |> Stub.retract_role(req)

      assert err.status == GRPC.Status.invalid_argument()
      assert Rbac.Repo.aggregate(Rbac.Repo.SubjectRoleBinding, :count, :id) == 1
    end

    test "Retract global role", state do
      alias Rbac.Repo.RbacRole
      alias Rbac.Store.{UserPermissions, ProjectAccess}
      alias Support.Factories.OrgRoleToProjRoleMappings

      nil_uuid = Rbac.Utils.Common.nil_uuid()

      # Setup: Create global roles and assign them to an user
      Support.Rbac.create_org_roles(nil_uuid)
      Support.Rbac.create_project_roles(nil_uuid)
      {_, global_admin} = RbacRole.get_role_by_name("Admin", "org_scope", nil_uuid)
      {_, proj_admin} = RbacRole.get_role_by_name("Admin", "project_scope", nil_uuid)
      OrgRoleToProjRoleMappings.insert(org_role_id: global_admin.id, proj_role_id: proj_admin.id)
      Support.Rbac.assign_org_role_by_name(nil_uuid, @user_id, "Admin")

      # Assign global admin role
      req = gen_retract_role_req(@user_id, nil_uuid)
      {:ok, _} = state.grpc_channel |> Stub.retract_role(req)

      # Since role has been removed, the user should not have access to the @org_id organization
      {:ok, rbi} = Rbac.RoleBindingIdentification.new(user_id: @user_id, org_id: @org_id)
      assert UserPermissions.read_user_permissions(rbi) == ""
      assert ProjectAccess.get_list_of_projects(@user_id, @org_id) == []
    end
  end

  describe "list_members" do
    alias InternalApi.RBAC.ListMembersRequest, as: Request
    @new_member_name "Adam Neely"
    @new_member UUID.generate()

    setup state do
      Support.Factories.RbacUser.insert(@new_member, @new_member_name)
      {:ok, state}
    end

    test "when page is null/nil", state do
      Support.Rbac.assign_org_role_by_name(@org_id, @user_id, "Admin")
      # This project membership should be ignored since we are fetching org members
      Support.Rbac.assign_project_role_by_name(@org_id, @user_id, @project_id, "Reader")

      req = %Request{org_id: @org_id}
      {:ok, %{members: [member], total_pages: 1}} = state.grpc_channel |> Stub.list_members(req)

      assert member.subject.subject_id == @user_id
      [subject_role_binding] = member.subject_role_bindings

      assert subject_role_binding.source ==
               :ROLE_BINDING_SOURCE_MANUALLY

      {:ok, admin_role} = Rbac.Repo.RbacRole.get_role_by_name("Admin", "org_scope", @org_id)
      assert subject_role_binding.role.id == admin_role.id
    end

    test "when page is not specified", state do
      Support.Rbac.assign_org_role_by_name(@org_id, @user_id, "Admin")
      # This project membership should be ignored since we are fetching org members
      Support.Rbac.assign_project_role_by_name(@org_id, @user_id, @project_id, "Reader")

      req = %Request{org_id: @org_id, page: %Request.Page{}}
      {:ok, %{members: [member], total_pages: 1}} = state.grpc_channel |> Stub.list_members(req)

      assert member.subject.subject_id == @user_id
      [subject_role_binding] = member.subject_role_bindings

      assert subject_role_binding.source == :ROLE_BINDING_SOURCE_MANUALLY

      {:ok, admin_role} = Rbac.Repo.RbacRole.get_role_by_name("Admin", "org_scope", @org_id)
      assert subject_role_binding.role.id == admin_role.id
    end

    test "when page size and number are specified", state do
      Support.Rbac.assign_org_role_by_name(@org_id, @user_id, "Admin")
      Support.Rbac.assign_org_role_by_name(@org_id, @new_member, "Admin")

      page_1_req = %Request{org_id: @org_id, page: %Request.Page{page_no: 0, page_size: 1}}
      page_2_req = %Request{org_id: @org_id, page: %Request.Page{page_no: 1, page_size: 1}}

      {:ok, %{members: [member1], total_pages: 2}} =
        state.grpc_channel |> Stub.list_members(page_1_req)

      {:ok, %{members: [member2], total_pages: 2}} =
        state.grpc_channel |> Stub.list_members(page_2_req)

      assert member1.subject.subject_id != member2.subject.subject_id
    end

    test "when filter by name is given", state do
      Support.Rbac.assign_org_role_by_name(@org_id, @user_id, "Admin", :okta)

      req = %Request{org_id: @org_id, member_name_contains: @user_name |> String.slice(1, 5)}
      {:ok, %{members: [member], total_pages: 1}} = state.grpc_channel |> Stub.list_members(req)

      assert member.subject.subject_id == @user_id
      [role_binding] = member.subject_role_bindings
      assert role_binding.source == :ROLE_BINDING_SOURCE_SCIM
    end

    test "when filter by role is given", state do
      {:ok, admin_role} = Rbac.Repo.RbacRole.get_role_by_name("Admin", "org_scope", @org_id)

      Support.Rbac.assign_org_role_by_name(@org_id, @user_id, "Member")
      Support.Rbac.assign_org_role_by_name(@org_id, @new_member, "Admin")

      req = %Request{org_id: @org_id, member_has_role: admin_role.id}
      {:ok, %{members: [member], total_pages: 1}} = state.grpc_channel |> Stub.list_members(req)

      assert member.subject.subject_id == @new_member
    end

    test "when listing project members", state do
      alias Support.Factories.OrgRoleToProjRoleMappings

      {:ok, third_user} = Support.Factories.RbacUser.insert(UUID.generate(), @user_name)

      # Two users are 'normal' members of the org
      Support.Rbac.assign_org_role_by_name(@org_id, @user_id, "Member")
      Support.Rbac.assign_org_role_by_name(@org_id, @new_member, "Member")
      # Third user has a special role within the org that grants access to all the projects
      {:ok, org_admn} = Rbac.Repo.RbacRole.get_role_by_name("Admin", "org_scope", @org_id)
      {:ok, proj_admin} = Rbac.Repo.RbacRole.get_role_by_name("Admin", "project_scope", @org_id)
      OrgRoleToProjRoleMappings.insert(org_role_id: org_admn.id, proj_role_id: proj_admin.id)
      Support.Rbac.assign_org_role_by_name(@org_id, third_user.id, "Admin")
      # One of them has a role directly assigned within the project
      Support.Rbac.assign_project_role_by_name(@org_id, @new_member, @project_id, "Reader")

      req = %Request{org_id: @org_id, project_id: @project_id, page: %Request.Page{}}

      {:ok, %{members: members, total_pages: 1}} = state.grpc_channel |> Stub.list_members(req)
      assert length(members) == 2

      manually_assigned_role = Enum.find(members, &(&1.subject.subject_id == @new_member))
      inherited_role = Enum.find(members, &(&1.subject.subject_id == third_user.id))

      assert manually_assigned_role.subject_role_bindings |> hd() |> Map.get(:source) ==
               :ROLE_BINDING_SOURCE_MANUALLY

      assert inherited_role.subject_role_bindings |> hd() |> Map.get(:source) ==
               :ROLE_BINDING_SOURCE_INHERITED_FROM_ORG_ROLE
    end
  end

  describe "count_members" do
    alias InternalApi.RBAC.CountMembersRequest, as: Request

    setup state do
      roles = ["Admin", "Member", "Owner"]

      1..3
      |> Enum.each(fn i ->
        {:ok, rbac_user} = Support.Factories.RbacUser.insert(UUID.generate(), "John Doe #{i}")

        Support.Rbac.assign_org_role_by_name(@org_id, rbac_user.id, Enum.at(roles, i - 1))
      end)

      {:ok, state}
    end

    test "Should return the total count of members", %{grpc_channel: channel} do
      request = %Request{org_id: @org_id}

      {:ok, %{members: members_count}} = channel |> Stub.count_members(request)

      assert members_count == 3
    end

    test "Should return not found error if organization is not found", %{grpc_channel: channel} do
      org_id = UUID.generate()
      request = %Request{org_id: org_id}

      assert {:error, grpc_error} = channel |> Stub.count_members(request)
      assert grpc_error.message =~ "Organization not found for id #{org_id}"
      assert grpc_error.status == GRPC.Status.not_found()
    end
  end

  describe "list_roles" do
    alias InternalApi.RBAC.ListRolesRequest, as: Request

    test "invalid req data", state do
      req = %Request{}
      {:error, grpc_error} = state.grpc_channel |> Stub.list_roles(req)

      assert grpc_error.message =~ "Invalid uuid"
      req = %Request{org_id: "not-valid-uuid"}

      {:error, grpc_error} = state.grpc_channel |> Stub.list_roles(req)
      assert grpc_error.message =~ "Invalid uuid"
    end

    @org_roles ["Admin", "Member", "Owner", "BillingAdmin"]
    test "only organization roles are returned", state do
      req = %Request{org_id: @org_id, scope: :SCOPE_ORG}
      {:ok, %{roles: roles}} = state.grpc_channel |> Stub.list_roles(req)

      Enum.each(roles, fn role ->
        assert role.name in @org_roles
        assert role.scope == :SCOPE_ORG
      end)
    end

    @project_roles ["Admin", "Contributor", "Reader"]
    test "only project roles are returned", state do
      req = %Request{org_id: @org_id, scope: :SCOPE_PROJECT}
      {:ok, %{roles: roles}} = state.grpc_channel |> Stub.list_roles(req)

      Enum.each(roles, fn role ->
        assert role.name in @project_roles
        role.scope == :SCOPE_PROJECT
      end)
    end

    test "organization and project roles are returned", state do
      req = %Request{org_id: @org_id}
      {:ok, %{roles: roles}} = state.grpc_channel |> Stub.list_roles(req)
      assert roles |> length == (@org_roles ++ @project_roles) |> length

      scopes =
        roles
        |> Enum.map(fn role -> role.scope end)
        |> Enum.uniq()
        |> Enum.sort()

      assert scopes ==
               [
                 :SCOPE_ORG,
                 :SCOPE_PROJECT
               ]
               |> Enum.sort()
    end

    test "error is returned if database query fails", state do
      with_mocks [
        {Rbac.Repo.RbacRole, [], [list_roles: fn _org_id, _scope_id -> raise "oops" end]}
      ] do
        req = %Request{org_id: @org_id}
        assert {:error, _e} = state.grpc_channel |> Stub.list_roles(req)
      end
    end
  end

  describe "describe_role" do
    alias InternalApi.RBAC.DescribeRoleRequest, as: Request

    test "when role does not exist", state do
      req = %Request{role_id: UUID.generate(), org_id: @org_id}
      {:error, err} = state.grpc_channel |> Stub.describe_role(req)
      assert err.status == GRPC.Status.not_found()
      assert err.message =~ "not found"
    end

    test "when role exists", state do
      alias Support.Factories.OrgRoleToProjRoleMappings
      {:ok, admin} = Rbac.Repo.RbacRole.get_role_by_name("Admin", "org_scope", @org_id)
      {:ok, reader} = Rbac.Repo.RbacRole.get_role_by_name("Reader", "project_scope", @org_id)
      OrgRoleToProjRoleMappings.insert(org_role_id: admin.id, proj_role_id: reader.id)

      req = %Request{role_id: admin.id, org_id: @org_id}
      {:ok, %{role: role}} = state.grpc_channel |> Stub.describe_role(req)

      assert admin.name == "Admin"
      assert role.id == admin.id
      assert role.org_id == @org_id
      assert role.maps_to.name == "Reader"
      assert Enum.map(role.rbac_permissions, & &1.name) |> Enum.sort() == @org_admin_permissions
    end
  end

  describe "refresh_collaborators" do
    alias InternalApi.RBAC.RefreshCollaboratorsRequest, as: Request
    alias InternalApi.Repository.Collaborator

    setup do
      {:ok, worker} = Rbac.Refresh.Worker.start_link()

      list_collaborators = %InternalApi.Repository.ListCollaboratorsResponse{
        next_page_token: "",
        collaborators: [
          %Collaborator{id: "2", login: "bar", permission: :ADMIN},
          %Collaborator{id: "3", login: "baz", permission: :WRITE},
          %Collaborator{id: "4", login: "bam", permission: :READ}
        ]
      }

      GrpcMock.stub(RepositoryMock, :list_collaborators, fn _, _ ->
        list_collaborators
      end)

      on_exit(fn ->
        Process.exit(worker, :kill)
      end)

      :ok
    end

    test "creates refresh request and calls worker", state do
      # Insert a couple more test projects
      project_id2 = UUID.generate()
      project_id3 = UUID.generate()
      Support.Projects.insert(project_id: project_id2, org_id: @org_id)
      Support.Projects.insert(project_id: project_id3, org_id: @org_id)

      req = %Request{org_id: @org_id}

      assert {:ok, %InternalApi.RBAC.RefreshCollaboratorsResponse{}} =
               Stub.refresh_collaborators(state.grpc_channel, req)

      # Verify refresh request was created with correct projects
      refresh_request =
        Rbac.Repo.CollaboratorRefreshRequest
        |> Rbac.Repo.get_by(org_id: @org_id)

      refute is_nil(refresh_request)
      assert refresh_request.org_id == @org_id

      # Verify all projects were included in the refresh request
      project_ids = refresh_request.remaining_project_ids |> Enum.sort()
      expected_project_ids = [@project_id, project_id2, project_id3] |> Enum.sort()
      assert project_ids == expected_project_ids

      # Wait for the refresh request to be processed
      :timer.sleep(2000)

      processed_request =
        Rbac.Repo.CollaboratorRefreshRequest
        |> Rbac.Repo.get(refresh_request.id)

      assert processed_request.state == :done
    end
  end

  describe "modify_role/2" do
    alias InternalApi.RBAC.ModifyRoleRequest, as: Request

    test "modify role that does not exist", state do
      req = %Request{
        role: %InternalApi.RBAC.Role{
          id: UUID.generate(),
          org_id: @org_id,
          scope: :SCOPE_ORG
        },
        requester_id: @requester_id
      }

      {:error, err} = state.grpc_channel |> Stub.modify_role(req)

      assert err.status == GRPC.Status.invalid_argument()
      assert err.message =~ "The role does not exist."
    end

    test "create a new role", state do
      alias Rbac.Repo
      {:ok, member_role} = Repo.RbacRole.get_role_by_name("Member", "org_scope", @org_id)
      {:ok, reader_role} = Repo.RbacRole.get_role_by_name("Reader", "project_scope", @org_id)

      req = %Request{
        role: %InternalApi.RBAC.Role{
          org_id: @org_id,
          scope: :SCOPE_ORG,
          name: "New Role",
          rbac_permissions: [
            %InternalApi.RBAC.Permission{
              id: Repo.Permission.get_permission_id("organization.delete")
            }
          ],
          maps_to: %InternalApi.RBAC.Role{id: reader_role.id},
          inherited_role: %InternalApi.RBAC.Role{id: member_role.id}
        },
        requester_id: @requester_id
      }

      {:ok, %{role: response_role}} = state.grpc_channel |> Stub.modify_role(req)
      {:ok, role_from_db} = Repo.RbacRole.get_role_by_name("New Role", "org_scope", @org_id)

      assert response_role.name == "New Role"
      assert response_role.id == role_from_db.id
      assert response_role.maps_to.id == reader_role.id
      assert response_role.inherited_role.id == member_role.id
      refute response_role.readonly
    end

    test "modify existing role", state do
      alias Rbac.Repo
      {:ok, member_role} = Repo.RbacRole.get_role_by_name("Member", "org_scope", @org_id)
      {:ok, reader_role} = Repo.RbacRole.get_role_by_name("Reader", "project_scope", @org_id)

      req = %Request{
        role: %InternalApi.RBAC.Role{
          id: member_role.id,
          org_id: @org_id,
          description: "Test description",
          rbac_permissions: [
            %InternalApi.RBAC.Permission{
              id: Repo.Permission.get_permission_id("organization.delete")
            }
          ],
          maps_to: %InternalApi.RBAC.Role{id: reader_role.id}
        },
        requester_id: @requester_id
      }

      member_role |> Repo.RbacRole.changeset(%{editable: true}) |> Repo.update()
      {:ok, %{role: response_role}} = state.grpc_channel |> Stub.modify_role(req)

      assert response_role.name == "Member"
      assert response_role.description == "Test description"
      assert response_role.id == member_role.id
      assert response_role.maps_to.id == reader_role.id
      assert response_role.inherited_role == nil
    end

    test "user is unauthorized to update roles", state do
      req = %Request{
        role: %InternalApi.RBAC.Role{org_id: @org_id},
        requester_id: @requester_id
      }

      {:error, err} = state.grpc_channel |> Stub.modify_role(req)

      assert err.status == GRPC.Status.permission_denied()
      assert err.message =~ "User unauthorized"
    end
  end

  # Function behind this endpoint (Store.RbacRole.delete_role) is testad in detail
  # within the test/rbac/store/rbac_role_test.exs script.
  describe "destroy_role/2" do
    alias InternalApi.RBAC.DestroyRoleRequest, as: Request

    test "successfully delete role", state do
      {:ok, role} = Rbac.Repo.RbacRole.get_role_by_name("Member", "org_scope", @org_id)
      role |> Rbac.Repo.RbacRole.changeset(%{editable: true}) |> Rbac.Repo.update()

      req = %Request{role_id: role.id, org_id: @org_id, requester_id: @requester_id}
      {:ok, resp} = state.grpc_channel |> Stub.destroy_role(req)

      assert resp.role_id == req.role_id
      {:error, :not_found} = Rbac.Repo.RbacRole.get_role_by_name("Member", "org_scope", @org_id)
    end

    test "user is unauthorized to update roles", state do
      req = %Request{role_id: UUID.generate(), org_id: @org_id, requester_id: @requester_id}

      {:error, err} = state.grpc_channel |> Stub.destroy_role(req)

      assert err.status == GRPC.Status.permission_denied()
      assert err.message =~ "User unauthorized"
    end
  end

  describe "subjects_have_roles" do
    alias InternalApi.RBAC.SubjectsHaveRolesRequest, as: Request

    test "invalid org_id passed", state do
      {:ok, role} = Rbac.Repo.RbacRole.get_role_by_name("Admin", "org_scope", @org_id)
      req = %Request{role_assignments: [gen_role_assignment(role.id, @user_id, "...")]}

      {:error, err_msg} = state.grpc_channel |> Stub.subjects_have_roles(req)
      assert err_msg.message =~ "Invalid uuid passed"
    end

    test "role does not exist anymore", state do
      req = %Request{role_assignments: [gen_role_assignment(UUID.generate(), @user_id, @org_id)]}

      {:ok, response} = state.grpc_channel |> Stub.subjects_have_roles(req)
      assert response.has_roles |> Enum.at(0) |> Map.get(:has_role) == false
    end

    test "first subject has the role, second does not", state do
      Support.Rbac.assign_org_role_by_name(@org_id, @user_id, "Admin")
      {:ok, role} = Rbac.Repo.RbacRole.get_role_by_name("Admin", "org_scope", @org_id)

      random_user = UUID.generate()

      req = %Request{
        role_assignments: [
          gen_role_assignment(role.id, @user_id, @org_id),
          gen_role_assignment(role.id, random_user, @org_id)
        ]
      }

      {:ok, response} = state.grpc_channel |> Stub.subjects_have_roles(req)

      assert response.has_roles |> Enum.at(0) |> Map.get(:has_role) == true
      assert response.has_roles |> Enum.at(1) |> Map.get(:has_role) == false
    end

    test "subject has the same role assigned twice (through different binding_sources)", state do
      Support.Rbac.assign_org_role_by_name(@org_id, @user_id, "Admin")
      Support.Rbac.assign_org_role_by_name(@org_id, @user_id, "Admin", :okta)
      {:ok, role} = Rbac.Repo.RbacRole.get_role_by_name("Admin", "org_scope", @org_id)

      req = %Request{role_assignments: [gen_role_assignment(role.id, @user_id, @org_id)]}
      {:ok, response} = state.grpc_channel |> Stub.subjects_have_roles(req)

      assert response.has_roles |> length() == 1
      assert(response.has_roles |> Enum.at(0) |> Map.get(:has_role) == true)
    end
  end

  describe "list_accessible_orgs" do
    alias InternalApi.RBAC.ListAccessibleOrgsRequest, as: Request

    test "invalid request", state do
      reqs = [%Request{}, %Request{user_id: "not-valid-uuid"}]

      Enum.each(reqs, fn req ->
        {:error, grpc_error} = state.grpc_channel |> Stub.list_accessible_orgs(req)
        assert grpc_error.message =~ "Invalid uuid"
      end)
    end

    test "If user has access to 2 orgs, return those ids", state do
      org1_id = UUID.generate()
      org2_id = UUID.generate()

      Support.Rbac.create_org_roles(org1_id)
      Support.Rbac.create_org_roles(org2_id)

      Support.Rbac.assign_org_role_by_name(org1_id, @user_id, "Admin")
      Support.Rbac.assign_org_role_by_name(org2_id, @user_id, "Member")

      req = %Request{user_id: @user_id}
      {:ok, resp} = state.grpc_channel |> Stub.list_accessible_orgs(req)
      assert Enum.sort([org1_id, org2_id]) == Enum.sort(resp.org_ids)
    end

    test "If user has two roles within one org, return that org just once", state do
      Support.Rbac.assign_org_role_by_name(@org_id, @user_id, "Admin")
      Support.Rbac.assign_org_role_by_name(@org_id, @user_id, "Member", :okta)

      req = %Request{user_id: @user_id}
      {:ok, resp} = state.grpc_channel |> Stub.list_accessible_orgs(req)
      assert [@org_id] == resp.org_ids
    end
  end

  describe "list_accessible_projects" do
    alias InternalApi.RBAC.ListAccessibleProjectsRequest, as: Request

    test "invalid request", state do
      reqs = [
        %Request{},
        %Request{org_id: "not-valid-uuid", user_id: @user_id},
        %Request{org_id: @org_id, user_id: "not-valid-uuid"}
      ]

      Enum.each(reqs, fn req ->
        {:error, grpc_error} = state.grpc_channel |> Stub.list_accessible_projects(req)
        assert grpc_error.message =~ "Invalid uuid"
      end)
    end

    test "return only projects that user has access to", state do
      project1_id = UUID.generate()
      project2_id = UUID.generate()
      project3_id = UUID.generate()
      org2_id = UUID.generate()

      Support.Rbac.create_org_roles(org2_id)
      Support.Rbac.create_project_roles(org2_id)

      Support.Rbac.assign_org_role_by_name(@org_id, @user_id, "Admin")
      Support.Rbac.assign_org_role_by_name(org2_id, @user_id, "Admin")

      Support.Rbac.assign_project_role_by_name(@org_id, @user_id, project1_id, "Reader")
      Support.Rbac.assign_project_role_by_name(@org_id, @user_id, project2_id, "Reader")
      Support.Rbac.assign_project_role_by_name(org2_id, @user_id, project3_id, "Reader")

      req = %Request{user_id: @user_id, org_id: @org_id}
      {:ok, resp} = state.grpc_channel |> Stub.list_accessible_projects(req)
      assert Enum.sort([project1_id, project2_id]) == Enum.sort(resp.project_ids)
    end

    test "returns empty list if cache lookup fails", state do
      with_mocks [
        {@store_backend, [:passthrough],
         [
           get: fn @project_access_store_name, _key -> {:error, "oops"} end
         ]}
      ] do
        req = %Request{user_id: @user_id, org_id: @org_id}
        {:ok, resp} = state.grpc_channel |> Stub.list_accessible_projects(req)
        assert resp.project_ids == []
      end
    end

    test "returns empty list if cache lookup raises", state do
      with_mocks [
        {@store_backend, [:passthrough],
         [
           get: fn @project_access_store_name, _key -> raise "oops" end
         ]}
      ] do
        req = %Request{user_id: @user_id, org_id: @org_id}
        {:ok, resp} = state.grpc_channel |> Stub.list_accessible_projects(req)
        assert resp.project_ids == []
      end
    end
  end

  describe "list_subjects" do
    alias InternalApi.RBAC.ListSubjectsRequest, as: Request

    test "invalid org_id returns error", state do
      req = %Request{org_id: "invalid-uuid", subject_ids: []}
      {:error, grpc_error} = state.grpc_channel |> Stub.list_subjects(req)
      assert grpc_error.message =~ "Invalid uuid"
    end

    test "returns subjects that are part of the organization", state do
      user1_id = UUID.generate()
      user2_id = UUID.generate()
      user3_id = UUID.generate()

      Support.Factories.RbacUser.insert(user1_id, "User One")
      Support.Factories.RbacUser.insert(user2_id, "User Two")
      Support.Factories.RbacUser.insert(user3_id, "User Three")

      Support.Rbac.assign_org_role_by_name(@org_id, user1_id, "Admin")
      Support.Rbac.assign_org_role_by_name(@org_id, user2_id, "Member")

      req = %Request{org_id: @org_id, subject_ids: [user1_id, user2_id, user3_id]}
      {:ok, %{subjects: subjects}} = state.grpc_channel |> Stub.list_subjects(req)

      assert length(subjects) == 2
      subject_ids = Enum.map(subjects, & &1.subject_id)
      assert user1_id in subject_ids
      assert user2_id in subject_ids
      refute user3_id in subject_ids
    end

    test "returns empty list when no subjects match", state do
      user_id = UUID.generate()
      Support.Factories.RbacUser.insert(user_id, "User One")

      req = %Request{org_id: @org_id, subject_ids: [user_id]}
      {:ok, %{subjects: subjects}} = state.grpc_channel |> Stub.list_subjects(req)

      assert subjects == []
    end

    test "returns subjects with correct type and display name", state do
      user_id = UUID.generate()
      Support.Factories.RbacUser.insert(user_id, "Test User")
      Support.Rbac.assign_org_role_by_name(@org_id, user_id, "Admin")

      req = %Request{org_id: @org_id, subject_ids: [user_id]}
      {:ok, %{subjects: subjects}} = state.grpc_channel |> Stub.list_subjects(req)

      assert length(subjects) == 1
      subject = hd(subjects)
      assert subject.subject_id == user_id
      assert subject.display_name == "Test User"
      assert subject.subject_type == :USER
    end

    test "returns empty list when subject_ids is empty", state do
      req = %Request{org_id: @org_id, subject_ids: []}
      {:ok, %{subjects: subjects}} = state.grpc_channel |> Stub.list_subjects(req)

      assert subjects == []
    end

    test "filters subjects by organization correctly", state do
      other_org_id = UUID.generate()
      user_id = UUID.generate()

      Support.Factories.RbacUser.insert(user_id, "User One")
      Support.Rbac.create_org_roles(other_org_id)
      Support.Rbac.assign_org_role_by_name(other_org_id, user_id, "Admin")

      req = %Request{org_id: @org_id, subject_ids: [user_id]}
      {:ok, %{subjects: subjects}} = state.grpc_channel |> Stub.list_subjects(req)

      assert subjects == []
    end
  end

  ###
  ### Helper functions
  ###

  @permissions "insider.global_roles.manage,organization.people.manage,project.access.manage,organization.custom_roles.manage"
  defp give_all_permissions do
    alias Rbac.Repo
    key = "user:#{@requester_id}_org:*_project:*"

    %Repo.UserPermissionsKeyValueStore{key: key, value: @permissions} |> Repo.insert()
  end

  defp gen_assign_role_req(subject_id, role_id, org_id, project_id \\ "") do
    %InternalApi.RBAC.AssignRoleRequest{
      role_assignment: gen_role_assignment(role_id, subject_id, org_id, project_id),
      requester_id: @requester_id
    }
  end

  defp gen_retract_role_req(subject_id, org_id, project_id \\ "") do
    %InternalApi.RBAC.RetractRoleRequest{
      role_assignment: gen_role_assignment("", subject_id, org_id, project_id),
      requester_id: @requester_id
    }
  end

  defp gen_role_assignment(role_id, subject_id, org_id, project_id \\ "") do
    %InternalApi.RBAC.RoleAssignment{
      role_id: role_id,
      subject: %InternalApi.RBAC.Subject{subject_id: subject_id},
      org_id: org_id,
      project_id: project_id
    }
  end

  defp register_project_api_response(state \\ :READY) do
    alias Support.Factories
    alias InternalApi.Projecthub.DescribeResponse
    alias InternalApi.Projecthub.Project.Status

    state = %Status{state: state}
    project = Factories.project(id: @project_id, org_id: @org_id) |> Map.replace(:status, state)
    project_resp = %DescribeResponse{metadata: Factories.response_meta(), project: project}

    GrpcMock.stub(ProjecthubMock, :describe, fn _, _ ->
      project_resp
    end)
  end

  defp assert_no_permissions_returned(grpc_channel) do
    Support.Rbac.assign_org_role_by_name(@org_id, @user_id, "Admin")

    req = %InternalApi.RBAC.ListUserPermissionsRequest{user_id: @user_id, org_id: @org_id}
    {:ok, %{permissions: permissions}} = grpc_channel |> Stub.list_user_permissions(req)

    assert permissions == []
  end
end
