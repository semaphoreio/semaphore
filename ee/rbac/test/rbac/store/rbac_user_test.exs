defmodule Rbac.Store.RbacUser.Test do
  use Rbac.RepoCase, async: true

  alias Rbac.Store.RbacUser
  alias Support.Factories

  @user_id Ecto.UUID.generate()
  @org_id Ecto.UUID.generate()
  @project_id Ecto.UUID.generate()

  describe "create/3" do
    test "create user with valid username" do
      assert Rbac.Repo.Subject |> Rbac.Repo.all() |> length == 0
      assert Rbac.Repo.RbacUser |> Rbac.Repo.all() |> length == 0

      assert RbacUser.create(@user_id, "test@mail.com", "test_name") == :ok

      assert Rbac.Repo.Subject |> Rbac.Repo.all() |> length == 1
      assert Rbac.Repo.RbacUser |> Rbac.Repo.all() |> length == 1
    end

    test "create already existing user" do
      Support.Factories.RbacUser.insert(@user_id)

      assert RbacUser.create(@user_id, "test@mail.com", "test_name") == :error

      assert Rbac.Repo.Subject |> Rbac.Repo.all() |> length == 1
      assert Rbac.Repo.RbacUser |> Rbac.Repo.all() |> length == 1
    end
  end

  describe "delete/1" do
    test "when user has both project and org roles assigned" do
      Factories.RbacUser.insert(@user_id)
      add_user_to_the_group(@user_id)
      assign_org_role(@user_id, @org_id)
      assign_project_role(@user_id, @org_id, @project_id)

      assert RbacUser.delete(@user_id) == :ok
      assert Rbac.Repo.aggregate(Rbac.Repo.RbacUser, :count, :id) == 0
      assert Rbac.Repo.aggregate(Rbac.Repo.UserGroupBinding, :count, :user_id) == 0
      assert Rbac.Repo.aggregate(Rbac.Repo.SubjectRoleBinding, :count, :id) == 0
      assert Rbac.Repo.aggregate(Rbac.Repo.SubjectRoleBinding, :count, :id) == 0
      assert Rbac.Repo.aggregate(Rbac.Repo.UserPermissionsKeyValueStore, :count, :key) == 0
      assert Rbac.Repo.aggregate(Rbac.Repo.ProjectAccessKeyValueStore, :count, :key) == 0
    end
  end

  describe "fetch/1" do
    test "when user exists" do
      name = "Hrafnkell"
      Factories.RbacUser.insert(@user_id, name)

      user = RbacUser.fetch(@user_id)

      assert user.id == @user_id
      assert user.name == name
    end
  end

  describe "fetch_users_without_oidc_connection/1" do
    test "when there are users without oidc connection" do
      Factories.RbacUser.insert(@user_id)
      Factories.RbacUser.insert(Ecto.UUID.generate())

      {page, users} = RbacUser.fetch_users_without_oidc_connection()

      assert page == 1
      assert length(users) == 2
    end

    test "when there are no users without oidc connection" do
      Factories.RbacUser.insert(@user_id)
      Factories.RbacUser.insert(Ecto.UUID.generate())
      Factories.OIDCUser.insert(@user_id)

      {page, users} = RbacUser.fetch_users_without_oidc_connection()

      assert page == 1
      assert length(users) == 1
    end

    test "when there are no users" do
      {page, users} = RbacUser.fetch_users_without_oidc_connection()

      assert page == 1
      assert users == []
    end

    test "can set limit" do
      Factories.RbacUser.insert(@user_id)
      Factories.RbacUser.insert(Ecto.UUID.generate())

      {page, users} = RbacUser.fetch_users_without_oidc_connection(1, 1)

      assert page == 1
      assert length(users) == 1

      {page, users} = RbacUser.fetch_users_without_oidc_connection(2, 1)
      assert page == 2
      assert length(users) == 1
    end
  end

  ###
  ### Helper functions
  ###

  defp add_user_to_the_group(user_id) do
    {:ok, group} = Factories.Group.insert()
    Factories.UserGroupBinding.insert(user_id: user_id, group_id: group.id)
  end

  defp assign_org_role(user_id, org_id) do
    {:ok, org_scope} = Support.Factories.Scope.insert("org_scope")
    {:ok, org_role} = Support.Factories.RbacRole.insert(org_id: org_id, scope_id: org_scope.id)
    Support.Factories.RolePermissionBinding.insert(rbac_role_id: org_role.id)
    {:ok, rbi} = Rbac.RoleBindingIdentification.new(user_id: user_id, org_id: org_id)
    Rbac.RoleManagement.assign_role(rbi, org_role.id, :manually_assigned)
  end

  defp assign_project_role(user_id, org_id, project_id) do
    {:ok, project_scope} = Support.Factories.Scope.insert("project_scope")

    {:ok, project_role} =
      Support.Factories.RbacRole.insert(org_id: org_id, scope_id: project_scope.id)

    Support.Factories.RolePermissionBinding.insert(rbac_role_id: project_role.id)

    {:ok, rbi} =
      Rbac.RoleBindingIdentification.new(
        user_id: user_id,
        org_id: org_id,
        project_id: project_id
      )

    Rbac.RoleManagement.assign_role(rbi, project_role.id, :manually_assigned)
  end
end
