defmodule Rbac.RoleManagement.Test do
  @moduledoc """
    This test suite is for integration tests. It check if role changes have been properly propagated to
    DB as well as 'rbac' and 'project_access' key-value stores
  """
  use Rbac.RepoCase, async: true

  import Ecto.Query
  import Mock

  alias Rbac.RoleManagement
  alias Rbac.RoleBindingIdentification, as: RBI
  alias Support.Collaborators

  @store_backend Application.compile_env(:rbac, :key_value_store_backend)
  @user_permissions_store_name Application.compile_env(:rbac, :user_permissions_store_name)

  @user_id "cb358a11-4185-4b5b-8829-5619805ac1fe"
  @user2_id "c24071c9-1d93-4953-9a2e-17d8ba0c5cc6"
  @org_id "7ae898b3-c511-4968-9641-fc8acda34853"
  @org2_id "960b71bb-8dbd-40f8-9542-af1ae7a86687"
  @project_id "2628268c-6ec8-4282-add2-c39df4473aeb"

  setup do
    Support.Rbac.create_org_roles(@org_id)
    Support.Rbac.create_project_roles(@org_id)

    Support.Factories.RbacUser.insert(@user_id)
    Support.Factories.RbacUser.insert(@user2_id)

    :ok
  end

  describe "has_role/2" do
    test "user_id not given", state do
      {:ok, rbi} = RBI.new(org_id: @org_id)
      assert RoleManagement.has_role(rbi, state[:org_role_id]) == false
    end

    test "empty role_id string given" do
      {:ok, rbi} = RBI.new(user_id: @user_id, org_id: @org_id)
      assert RoleManagement.has_role(rbi, "") == false
    end

    test "random non-existent role_id returns false" do
      {:ok, rbi} = RBI.new(user_id: @user_id, org_id: @org_id, project_id: @project_id)
      assert RoleManagement.has_role(rbi, Ecto.UUID.generate()) == false
    end

    test "user that has given org_level role" do
      Support.Rbac.assign_org_role_by_name(@org_id, @user_id, "Admin")
      {:ok, role} = Rbac.Repo.RbacRole.get_role_by_name("Admin", "org_scope", @org_id)

      {:ok, rbi} = RBI.new(user_id: @user_id, org_id: @org_id)
      assert RoleManagement.has_role(rbi, role.id) == true
    end

    test "user that has given project_level role" do
      Support.Rbac.assign_org_role_by_name(@org_id, @user_id, "Admin")
      Support.Rbac.assign_project_role_by_name(@org_id, @user_id, @project_id, "Reader")
      {:ok, role} = Rbac.Repo.RbacRole.get_role_by_name("Reader", "project_scope", @org_id)

      {:ok, rbi} = RBI.new(user_id: @user_id, org_id: @org_id, project_id: @project_id)
      assert RoleManagement.has_role(rbi, role.id) == true
    end

    test "user does not have given role", state do
      {:ok, rbi} = RBI.new(user_id: @user_id, org_id: @org_id, project_id: @project_id)
      assert RoleManagement.has_role(rbi, state[:org_role_id]) == false
      assert RoleManagement.has_role(rbi, state[:project_role_id]) == false
    end

    test "user has same role assigned twice (from different sources)" do
      Support.Rbac.assign_org_role_by_name(@org_id, @user_id, "Admin", :manually_assigned)
      Support.Rbac.assign_org_role_by_name(@org_id, @user_id, "Admin", :okta)
      {:ok, role} = Rbac.Repo.RbacRole.get_role_by_name("Admin", "org_scope", @org_id)

      {:ok, rbi} = RBI.new(user_id: @user_id, org_id: @org_id)
      assert RoleManagement.has_role(rbi, role.id) == true
    end
  end

  describe "user_part_of_org/2" do
    test "user does have a role within the org" do
      Support.Rbac.assign_org_role_by_name(@org_id, @user_id, "Admin")
      assert RoleManagement.user_part_of_org?(@user_id, @org_id) == true
    end

    test "user does not have a role within the org" do
      Support.Rbac.assign_org_role_by_name(@org_id, @user_id, "Admin")

      assert RoleManagement.user_part_of_org?(@user2_id, @org_id) == false
      assert RoleManagement.user_part_of_org?(@user_id, @org2_id) == false
    end
  end

  describe "assign_role/3" do
    test "user_id is not given" do
      {:ok, rbi} = RBI.new(org_id: @org_id)

      {:error, _} = RoleManagement.assign_role(rbi, Ecto.UUID.generate(), :okta)
    end

    test "org_id is not given" do
      {:ok, rbi} = RBI.new(user_id: @user_id)

      {:error, _} = RoleManagement.assign_role(rbi, Ecto.UUID.generate(), :okta)
    end

    test "organization_role and project_id are given" do
      {:ok, rbi} = RBI.new(user_id: @user_id, org_id: @org_id, project_id: @project_id)

      {:ok, role} = Rbac.Repo.RbacRole.get_role_by_name("Admin", "org_scope", @org_id)
      {:error, _} = RoleManagement.assign_role(rbi, role.id, :okta)
    end

    test "project_role is given, but project_id is not" do
      {:ok, rbi} = RBI.new(user_id: @user_id, org_id: @org_id)
      {:ok, role} = Rbac.Repo.RbacRole.get_role_by_name("Admin", "project_scope", @org_id)

      {:error, _} = RoleManagement.assign_role(rbi, role.id, :manually_assigned)
    end

    test "Can't assign project level role if user is not org member" do
      {:ok, rbi} = RBI.new(user_id: @user_id, org_id: @org_id, project_id: @project_id)
      {:ok, role} = Rbac.Repo.RbacRole.get_role_by_name("Admin", "project_scope", @org_id)

      {:error, _} = RoleManagement.assign_role(rbi, role.id, :manually_assigned)
    end

    test "valid assign_role call" do
      # User must be already org member in order to have project role assigned
      Support.Rbac.assign_org_role_by_name(@org_id, @user_id, "Admin")
      Support.Rbac.assign_project_role_by_name(@org_id, @user_id, @project_id, "Reader")

      {:ok, proj_role} = Rbac.Repo.RbacRole.get_role_by_name("Reader", "project_scope", @org_id)
      assert has_role_binding?(@user_id, @org_id, @project_id, proj_role.id)
      assert user_has_access_to_projects?(@user_id, @org_id, [@project_id])
    end

    # When org level role is assigned, collaborators should be checked to see whether
    # new org member should be assigned some project level roles based on collaborators list
    test "assign org_level role" do
      Collaborators.insert_user(user_id: @user_id, github_uid: "1")
      Support.Projects.insert(project_id: @project_id, org_id: @org_id)
      Collaborators.insert(github_uid: "1", project_id: @project_id)

      {:ok, org_role} = Rbac.Repo.RbacRole.get_role_by_name("Member", "org_scope", @org_id)
      {:ok, proj_role} = Rbac.Repo.RbacRole.get_role_by_name("Admin", "project_scope", @org_id)
      Support.Factories.RepoToRoleMapping.insert(org_id: @org_id, admin_role_id: proj_role.id)
      Support.Rbac.assign_org_role_by_name(@org_id, @user_id, "Member")

      assert has_role_binding?(@user_id, @org_id, :is_nil, org_role.id)
      assert has_role_binding?(@user_id, @org_id, @project_id, proj_role.id, :github)
      assert user_has_access_to_projects?(@user_id, @org_id, [@project_id])
    end

    test "valid assign_role call when cache is not available" do
      with_mocks [
        {@store_backend, [:passthrough],
         [
           put: fn @user_permissions_store_name, _key, _permissions -> {:error, :cache_error} end
         ]}
      ] do
        {:ok, org_role} = Rbac.Repo.RbacRole.get_role_by_name("Member", "org_scope", @org_id)
        {:ok, rbi} = RBI.new(user_id: @user_id, org_id: @org_id, project_id: @project_id)
        {:error, _} = RoleManagement.assign_role(rbi, org_role.id, :manually_assigned)

        refute has_role_binding?(@user_id, @org_id, :is_nil, org_role.id)
        refute user_has_access_to_projects?(@user_id, @org_id, [@project_id])
      end
    end

    # Next two tests test to see whether assign_role operation is idempotent
    test "assign same organization role twice in a row" do
      {:ok, org_role} = Rbac.Repo.RbacRole.get_role_by_name("Member", "org_scope", @org_id)
      {:ok, rbi} = RBI.new(user_id: @user_id, org_id: @org_id)

      {:ok, _} = RoleManagement.assign_role(rbi, org_role.id, :manually_assigned)
      {:ok, _} = RoleManagement.assign_role(rbi, org_role.id, :manually_assigned)

      assert has_role_binding?(@user_id, @org_id, :is_nil, org_role.id)
      assert Rbac.Repo.SubjectRoleBinding |> Rbac.Repo.all() |> length == 1
    end

    test "assign same project role twice in a row" do
      # User must be already org member in order to have project role assigned
      Support.Rbac.assign_org_role_by_name(@org_id, @user_id, "Member")

      {:ok, proj_role} = Rbac.Repo.RbacRole.get_role_by_name("Admin", "project_scope", @org_id)
      {:ok, rbi} = RBI.new(user_id: @user_id, org_id: @org_id, project_id: @project_id)

      {:ok, _} = RoleManagement.assign_role(rbi, proj_role.id, :manually_assigned)
      {:ok, _} = RoleManagement.assign_role(rbi, proj_role.id, :manually_assigned)

      assert has_role_binding?(@user_id, @org_id, @project_id, proj_role.id)
      assert Rbac.Repo.SubjectRoleBinding |> Rbac.Repo.all() |> length == 2
      assert user_has_access_to_projects?(@user_id, @org_id, [@project_id])
    end

    test "assign role to group which already has members" do
      {:ok, group} = Support.Factories.Group.insert(org_id: @org_id)
      Support.Factories.UserGroupBinding.insert(group_id: group.id, user_id: @user_id)

      {:ok, rbi} = RBI.new(user_id: @user_id, org_id: @org_id)

      assert "" == Rbac.Store.UserPermissions.read_user_permissions(rbi)
      Support.Rbac.assign_org_role_by_name(@org_id, group.id, "Admin")
      refute "" == Rbac.Store.UserPermissions.read_user_permissions(rbi)
    end
  end

  describe "assign_project_roles_to_repo_collaborators/1" do
    # If collaborator isn't member of the organization that owns the project, he cant be assigned
    # a project level role
    test "One collaborator exists, but he does not have org level role" do
      Collaborators.insert_user(user_id: @user_id, github_uid: "1")
      Support.Projects.insert(project_id: @project_id, org_id: @org_id, provider: "bitbucket")
      Collaborators.insert(github_uid: "1", project_id: @project_id)

      {:ok, proj_role} = Rbac.Repo.RbacRole.get_role_by_name("Admin", "project_scope", @org_id)
      Support.Factories.RepoToRoleMapping.insert(org_id: @org_id, admin_role_id: proj_role.id)

      {:ok, rbi} = RBI.new(org_id: @org_id, project_id: @project_id)
      {:ok, _} = RoleManagement.assign_project_roles_to_repo_collaborators(rbi)

      refute has_role_binding?(@user_id, @org_id, @project_id, proj_role.id)
      refute user_has_access_to_projects?(@user_id, @org_id, [@project_id])
    end

    test "Assign roles to collaborators based on project_id" do
      alias Support.Factories.RepoToRoleMapping

      # In order for assign_project_roles_to_repo_collaborators to work, org level roles must already be assigned.
      Support.Rbac.assign_org_role_by_name(@org_id, @user2_id, "Member")
      Support.Rbac.assign_org_role_by_name(@org_id, @user_id, "Member")

      Collaborators.insert_user(user_id: @user_id, github_uid: "1")
      Collaborators.insert_user(user_id: @user2_id, github_uid: "2")
      Collaborators.insert(github_uid: "1", project_id: @project_id)
      Collaborators.insert(github_uid: "2", project_id: @project_id, admin: false, push: false)

      Support.Projects.insert(project_id: @project_id, org_id: @org_id)

      {:ok, admin} = Rbac.Repo.RbacRole.get_role_by_name("Admin", "project_scope", @org_id)
      {:ok, reader} = Rbac.Repo.RbacRole.get_role_by_name("Reader", "project_scope", @org_id)
      RepoToRoleMapping.insert(org_id: @org_id, admin_role_id: admin.id, pull_role_id: reader.id)

      {:ok, project_rbi} = RBI.new(org_id: @org_id, project_id: @project_id)
      {:ok, _} = RoleManagement.assign_project_roles_to_repo_collaborators(project_rbi)

      assert has_role_binding?(@user_id, @org_id, @project_id, admin.id, :github)
      assert has_role_binding?(@user2_id, @org_id, @project_id, reader.id, :github)
      assert user_has_access_to_projects?(@user_id, @org_id, [@project_id])
      assert user_has_access_to_projects?(@user2_id, @org_id, [@project_id])
    end

    test "Assign roles to collaborators based on user_id" do
      # In order for assign_project_roles_to_repo_collaborators to work, org level roles must already be assigned.
      Support.Rbac.assign_org_role_by_name(@org_id, @user_id, "Member")
      Support.Rbac.assign_org_role_by_name(@org_id, @user2_id, "Member")

      Collaborators.insert_user(user_id: @user_id, github_uid: "1")
      Collaborators.insert_user(user_id: @user2_id, github_uid: "2")
      Collaborators.insert(github_uid: "1", project_id: @project_id)
      Collaborators.insert(github_uid: "2", project_id: @project_id)

      Support.Projects.insert(project_id: @project_id, org_id: @org_id)

      {:ok, admin} = Rbac.Repo.RbacRole.get_role_by_name("Admin", "project_scope", @org_id)
      Support.Factories.RepoToRoleMapping.insert(org_id: @org_id, admin_role_id: admin.id)

      {:ok, rbi_for_user1} = RBI.new(user_id: @user_id)
      {:ok, _} = RoleManagement.assign_project_roles_to_repo_collaborators(rbi_for_user1)

      assert has_role_binding?(@user_id, @org_id, @project_id, admin.id, :github)
      refute has_role_binding?(@user2_id, @org_id, @project_id, admin.id, :github)
      assert user_has_access_to_projects?(@user_id, @org_id, [@project_id])
      refute user_has_access_to_projects?(@user2_id, @org_id, [@project_id])
    end

    test "Collaborator already has multiple org lvl roles" do
      alias Support.Factories.RepoToRoleMapping

      Support.Collaborators.insert_user(user_id: @user_id, github_uid: "1")
      Support.Collaborators.insert(github_uid: "1", project_id: @project_id)
      Support.Projects.insert(project_id: @project_id, org_id: @org_id)

      {:ok, admin} = Rbac.Repo.RbacRole.get_role_by_name("Admin", "project_scope", @org_id)
      {:ok, reader} = Rbac.Repo.RbacRole.get_role_by_name("Reader", "project_scope", @org_id)
      RepoToRoleMapping.insert(org_id: @org_id, admin_role_id: admin.id, pull_role_id: reader.id)

      Support.Rbac.assign_org_role_by_name(@org_id, @user_id, "Member")
      Support.Rbac.assign_org_role_by_name(@org_id, @user_id, "Admin", :okta)

      {:ok, project_rbi} = RBI.new(org_id: @org_id, project_id: @project_id)
      {:ok, _} = RoleManagement.assign_project_roles_to_repo_collaborators(project_rbi)

      assert user_has_access_to_projects?(@user_id, @org_id, [@project_id])
    end

    test "Organization does not have RepoToRoleMapping" do
      Support.Rbac.assign_org_role_by_name(@org_id, @user_id, "Member")
      Collaborators.insert_user(user_id: @user_id, github_uid: "1")
      Collaborators.insert(github_uid: "1", project_id: @project_id)
      Support.Projects.insert(project_id: @project_id, org_id: @org_id)

      # Note: We deliberately do NOT create a RepoToRoleMapping for this org

      {:ok, project_rbi} = RBI.new(org_id: @org_id, project_id: @project_id)

      # Should succeed but skip role assignment due to missing RepoToRoleMapping
      {:ok, _} = RoleManagement.assign_project_roles_to_repo_collaborators(project_rbi)

      # Verify no project role was assigned to the collaborator
      {:ok, admin} = Rbac.Repo.RbacRole.get_role_by_name("Admin", "project_scope", @org_id)
      refute has_role_binding?(@user_id, @org_id, @project_id, admin.id, :github)
      refute user_has_access_to_projects?(@user_id, @org_id, [@project_id])
    end
  end

  describe "retract_role/2" do
    test "retract all roles from a single user" do
      Support.Rbac.assign_org_role_by_name(@org_id, @user_id, "Member")
      Support.Rbac.assign_project_role_by_name(@org_id, @user_id, @project_id, "Reader")

      assert Rbac.Repo.SubjectRoleBinding |> Rbac.Repo.all() |> length == 2

      {:ok, rbi_for_retracting_roles} = RBI.new(user_id: @user_id)
      {:ok, _} = Rbac.RoleManagement.retract_roles(rbi_for_retracting_roles)

      assert Rbac.Repo.SubjectRoleBinding |> Rbac.Repo.all() |> length == 0
      refute user_has_access_to_projects?(@user_id, @org_id, [@project_id])
    end

    test "retract roles only from one binding source" do
      Support.Rbac.assign_org_role_by_name(@org_id, @user_id, "Member")
      Support.Rbac.assign_project_role_by_name(@org_id, @user_id, @project_id, "Reader")
      Support.Rbac.assign_project_role_by_name(@org_id, @user_id, @project_id, "Admin", :github)

      {:ok, rbi} = RBI.new(user_id: @user_id, org_id: @org_id, project_id: @project_id)

      assert Rbac.Repo.SubjectRoleBinding |> Rbac.Repo.all() |> length() == 3
      cache_permissions = Rbac.Store.UserPermissions.read_user_permissions(rbi)
      cache_permissions = String.split(cache_permissions, ",")
      assert "project.view" in cache_permissions && "project.delete" in cache_permissions

      RoleManagement.retract_roles(rbi, :github)

      assert Rbac.Repo.SubjectRoleBinding |> Rbac.Repo.all() |> length() == 2
      cache_permissions = Rbac.Store.UserPermissions.read_user_permissions(rbi)
      cache_permissions = String.split(cache_permissions, ",")
      assert "project.view" in cache_permissions && "project.delete" not in cache_permissions

      assert user_has_access_to_projects?(@user_id, @org_id, [@project_id])
    end

    test "dont retract roles if cache is not available" do
      with_mocks [
        {@store_backend, [:passthrough],
         [
           delete: fn _cache_name, _keys_to_delete -> {:error, "cache_error"} end
         ]}
      ] do
        Support.Rbac.assign_org_role_by_name(@org_id, @user_id, "Member")
        Support.Rbac.assign_project_role_by_name(@org_id, @user_id, @project_id, "Admin")

        assert Rbac.Repo.SubjectRoleBinding |> Rbac.Repo.all() |> length == 2
        assert user_has_access_to_projects?(@user_id, @org_id, [@project_id])

        {:ok, rbi} = RBI.new(user_id: @user_id, org_id: @org_id, project_id: @project_id)
        {:error, _} = Rbac.RoleManagement.retract_roles(rbi)

        assert Rbac.Repo.SubjectRoleBinding |> Rbac.Repo.all() |> length == 2
        assert user_has_access_to_projects?(@user_id, @org_id, [@project_id])
      end
    end

    test "when you retract role from group, remove permissions from it's users as well" do
      alias Rbac.Store.UserPermissions

      Support.Rbac.assign_org_role_by_name(@org_id, @user_id, "Member")
      {:ok, group} = Support.Factories.Group.insert(org_id: @org_id)
      Support.Factories.UserGroupBinding.insert(group_id: group.id, user_id: @user_id)

      {:ok, user_rbi} = RBI.new(user_id: @user_id, org_id: @org_id)
      assert UserPermissions.read_user_permissions(user_rbi) =~ "organization.view"

      Support.Rbac.assign_org_role_by_name(@org_id, group.id, "Owner")
      assert UserPermissions.read_user_permissions(user_rbi) =~ "organization.delete"

      {:ok, group_rbi} = RBI.new(user_id: group.id, org_id: @org_id)
      RoleManagement.retract_roles(group_rbi)

      refute UserPermissions.read_user_permissions(user_rbi) =~ "organization.delete"
      assert UserPermissions.read_user_permissions(user_rbi) =~ "organization.view"
    end
  end

  describe "fetch_subject_role_bindings/2" do
    import RoleManagement, only: [fetch_subject_role_bindings: 1, fetch_subject_role_bindings: 2]

    test "with user" do
      Support.Rbac.assign_org_role_by_name(@org_id, @user_id, "Member")

      {:ok, rbi} = RBI.new(user_id: @user_id, org_id: @org_id)
      {bindings, _} = fetch_subject_role_bindings(rbi)
      assert length(bindings) == 1

      {:ok, rbi} = RBI.new(user_id: @user2_id, org_id: @org_id)
      {bindings, _} = fetch_subject_role_bindings(rbi)
      assert Enum.empty?(bindings)
    end

    test "with project" do
      Support.Rbac.assign_org_role_by_name(@org_id, @user_id, "Member")
      Support.Rbac.assign_project_role_by_name(@org_id, @user_id, @project_id, "Reader")

      {:ok, rbi} = RBI.new(user_id: @user_id, org_id: @org_id, project_id: @project_id)
      {[binding], _} = fetch_subject_role_bindings(rbi)
      assert length(binding.role_bindings) == 1

      {:ok, rbi} = RBI.new(user_id: @user_id, org_id: @org_id)
      {[binding], _} = fetch_subject_role_bindings(rbi)
      assert length(binding.role_bindings) == 2

      {:ok, rbi} = RBI.new(user_id: @user_id, org_id: @org_id, project_id: :is_nil)
      {[binding], _} = fetch_subject_role_bindings(rbi)
      assert length(binding.role_bindings) == 1
    end

    test "with role" do
      Support.Rbac.assign_org_role_by_name(@org_id, @user_id, "Member")

      {:ok, rbi} = RBI.new(user_id: @user_id, org_id: @org_id)
      {:ok, org_role} = Rbac.Repo.RbacRole.get_role_by_name("Member", "org_scope", @org_id)
      {:ok, proj_role} = Rbac.Repo.RbacRole.get_role_by_name("Reader", "project_scope", @org_id)

      {[binding], _} = fetch_subject_role_bindings(rbi, role_id: org_role.id)
      assert length(binding.role_bindings) == 1

      {bindings, _} = fetch_subject_role_bindings(rbi, role_id: proj_role.id)
      assert Enum.empty?(bindings)
    end

    test "with binding source" do
      Support.Rbac.assign_org_role_by_name(@org_id, @user_id, "Member")
      Support.Rbac.assign_project_role_by_name(@org_id, @user_id, @project_id, "Reader", :github)

      {:ok, rbi} = RBI.new(user_id: @user_id, org_id: @org_id, project_id: @project_id)
      {[binding], _} = fetch_subject_role_bindings(rbi, binding_source: :github)
      assert length(binding.role_bindings) == 1

      {:ok, rbi} = RBI.new(user_id: @user_id, org_id: @org_id, project_id: @project_id)
      {bindings, _} = fetch_subject_role_bindings(rbi, binding_source: :manually_assigned)
      assert Enum.empty?(bindings)
    end

    test "searching by name" do
      Support.Rbac.assign_org_role_by_name(@org_id, @user_id, "Member")

      subject = Rbac.Repo.Subject.find_by_id(@user_id)
      {:ok, rbi} = RBI.new(user_id: @user_id, org_id: @org_id)

      # using proper name
      {[binding], _} = fetch_subject_role_bindings(rbi, subject_name: subject.name)
      assert length(binding.role_bindings) == 1

      # using some other name
      {bindings, _} = fetch_subject_role_bindings(rbi, subject_name: "not-this-one")
      assert Enum.empty?(bindings)
    end

    test "searching by subject type" do
      Support.Rbac.assign_org_role_by_name(@org_id, @user_id, "Member")
      {:ok, rbi} = RBI.new(org_id: @org_id)

      {[binding], _} = fetch_subject_role_bindings(rbi, subject_type: "user")
      assert length(binding.role_bindings) == 1

      {bindings, _} = fetch_subject_role_bindings(rbi, subject_type: "group")
      assert Enum.empty?(bindings)

      {:ok, group} = Support.Factories.Group.insert(org_id: @org_id)
      Support.Rbac.assign_org_role_by_name(@org_id, group.id, "Admin")

      {[binding], _} = fetch_subject_role_bindings(rbi, subject_type: "group")
      assert length(binding.role_bindings) == 1
    end
  end

  ###
  ### Helper functions
  ###

  defp has_role_binding?(subject_id, org_id, proj_id, role_id, source \\ :manually_assigned) do
    Rbac.Repo.SubjectRoleBinding
    |> add_where_for_subject(subject_id)
    |> add_where_for_org(org_id)
    |> add_where_for_project(proj_id)
    |> add_where_for_role(role_id)
    |> add_where_for_source(source)
    |> Rbac.Repo.exists?()
  end

  defp add_where_for_subject(query, nil), do: query
  defp add_where_for_subject(query, id), do: query |> where([r], r.subject_id == ^id)
  defp add_where_for_org(query, nil), do: query
  defp add_where_for_org(query, id), do: query |> where([r], r.org_id == ^id)
  defp add_where_for_project(query, nil), do: query
  defp add_where_for_project(query, :is_nil), do: query |> where([r], is_nil(r.project_id))
  defp add_where_for_project(query, id), do: query |> where([r], r.project_id == ^id)
  defp add_where_for_role(query, nil), do: query
  defp add_where_for_role(query, id), do: query |> where([r], r.role_id == ^id)
  defp add_where_for_source(query, nil), do: query
  defp add_where_for_source(query, source), do: query |> where([r], r.binding_source == ^source)

  defp user_has_access_to_projects?(user_id, org_id, project_ids) when is_list(project_ids) do
    project_ids_in_store = Rbac.Store.ProjectAccess.get_list_of_projects(user_id, org_id)
    Enum.sort(project_ids) == Enum.sort(project_ids_in_store)
  end
end
