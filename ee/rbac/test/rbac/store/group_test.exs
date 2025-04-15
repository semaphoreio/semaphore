defmodule Rbac.Store.Group.Test do
  use Rbac.RepoCase, async: true

  alias Rbac.Store.Group
  alias Rbac.Repo

  import Ecto.Query
  import Mock

  @org_id Ecto.UUID.generate()
  setup do
    {:ok, user} = Support.Factories.RbacUser.insert()

    Support.Rbac.create_org_roles(@org_id)
    Support.Rbac.create_project_roles(@org_id)
    Support.Rbac.assign_org_role_by_name(@org_id, user.id, "Member")

    {:ok, group} = Support.Factories.Group.insert(org_id: @org_id)

    {:ok,
     %{
       user_id: user.id,
       group: group
     }}
  end

  describe "add_to_group/2" do
    test "when group does not exist", ctx do
      group = %Repo.Group{id: Ecto.UUID.generate(), org_id: Ecto.UUID.generate()}
      {:error, :user_not_in_org} = Group.add_to_group(group, ctx.user_id)
    end

    test "when user is not part of the same org", ctx do
      {:ok, user} = Support.Factories.RbacUser.insert()
      {:error, :user_not_in_org} = Group.add_to_group(ctx.group, user.id)
    end

    test "user is added to a group, which is part of the given project", ctx do
      Support.Rbac.assign_org_role_by_name(@org_id, ctx.group.id, "BillingAdmin")

      proj_id = Ecto.UUID.generate()
      Support.Rbac.assign_project_role_by_name(@org_id, ctx.group.id, proj_id, "Reader")

      :ok = Group.add_to_group(ctx.group, ctx.user_id)

      org_permissions = Repo.UserPermissionsKeyValueStore |> where([up], up.key == ^"user:#{ctx.user_id}_org:#{@org_id}_project:*") |> Repo.one()
      assert org_permissions.value =~ "organization.view"
      assert org_permissions.value =~ "organization.billing.manage"

      project_permissions = Repo.UserPermissionsKeyValueStore |> where([up], up.key == ^"user:#{ctx.user_id}_org:#{@org_id}_project:#{proj_id}") |> Repo.one()
      assert project_permissions.value == "project.view"

      accesible_projects = Repo.ProjectAccessKeyValueStore |> where([pa], pa.key == ^"user:#{ctx.user_id}_org:#{@org_id}") |> Repo.one()
      assert accesible_projects.value == proj_id
    end

    test "when something goes wrong during the transaction", ctx do
      Support.Rbac.assign_org_role_by_name(@org_id, ctx.group.id, "BillingAdmin")

      proj_id = Ecto.UUID.generate()
      Support.Rbac.assign_project_role_by_name(@org_id, ctx.group.id, proj_id, "Reader")

      with_mocks [
        {Rbac.Store.ProjectAccess, [:passthrough], [add_project_access: fn _ -> :error end]}
      ] do
        {:error, :cant_add_project_acces_to_store} = Group.add_to_group(ctx.group, ctx.user_id)
      end

      org_permissions = Repo.UserPermissionsKeyValueStore |> where([up], up.key == ^"user:#{ctx.user_id}_org:#{@org_id}_project:*") |> Repo.one()
      assert org_permissions.value == "organization.view"
    end

    test "when runtime error occurs during the transaction", ctx do
      Support.Rbac.assign_org_role_by_name(@org_id, ctx.group.id, "BillingAdmin")

      proj_id = Ecto.UUID.generate()
      Support.Rbac.assign_project_role_by_name(@org_id, ctx.group.id, proj_id, "Reader")

      with_mocks [
        {Rbac.Store.ProjectAccess, [:passthrough],
         [add_project_access: fn _ -> raise "Error" end]}
      ] do
        try do
          {:error, :cant_add_project_acces_to_store} = Group.add_to_group(ctx.group, ctx.user_id)
        rescue
          e -> e
        end
      end

      org_permissions = Repo.UserPermissionsKeyValueStore |> where([up], up.key == ^"user:#{ctx.user_id}_org:#{@org_id}_project:*") |> Repo.one()
      assert org_permissions.value == "organization.view"
    end
  end

  describe "remove_from_group/2" do
    test "removes user from a group", ctx do
      Support.Rbac.assign_org_role_by_name(@org_id, ctx.group.id, "BillingAdmin")

      proj_id = Ecto.UUID.generate()
      Support.Rbac.assign_project_role_by_name(@org_id, ctx.group.id, proj_id, "Reader")

      # In tests above we validate if this function works, here we consider it does
      :ok = Group.add_to_group(ctx.group, ctx.user_id)
      :ok = Group.remove_from_group(ctx.group, ctx.user_id)

      org_permissions = Repo.UserPermissionsKeyValueStore |> where([up], up.key == ^"user:#{ctx.user_id}_org:#{@org_id}_project:*") |> Repo.one()
      assert org_permissions.value =~ "organization.view"

      refute Repo.UserPermissionsKeyValueStore |> where([up], up.key == ^"user:#{ctx.user_id}_org:#{@org_id}_project:#{proj_id}") |> Repo.exists?()
      refute Repo.ProjectAccessKeyValueStore |> where([pa], pa.key == ^"user:#{ctx.user_id}_org:#{@org_id}") |> Repo.exists?()
    end

    test "when something goes wrong during the transaction", ctx do
      Support.Rbac.assign_org_role_by_name(@org_id, ctx.group.id, "BillingAdmin")

      proj_id = Ecto.UUID.generate()
      Support.Rbac.assign_project_role_by_name(@org_id, ctx.group.id, proj_id, "Reader")
      :ok = Group.add_to_group(ctx.group, ctx.user_id)

      with_mocks [
        {Rbac.Store.UserPermissions, [:passthrough], [add_permissions: fn _ -> :error end]}
      ] do
        {:error, :cache_refresh_error} = Group.remove_from_group(ctx.group, ctx.user_id)
      end

      org_permissions = Repo.UserPermissionsKeyValueStore |> where([up], up.key == ^"user:#{ctx.user_id}_org:#{@org_id}_project:*") |> Repo.one()
      assert org_permissions.value =~ "organization.view"
      assert org_permissions.value =~ "organization.billing.manage"

      project_permissions = Repo.UserPermissionsKeyValueStore |> where([up], up.key == ^"user:#{ctx.user_id}_org:#{@org_id}_project:#{proj_id}") |> Repo.one()
      assert project_permissions.value == "project.view"

      accesible_projects = Repo.ProjectAccessKeyValueStore |> where([pa], pa.key == ^"user:#{ctx.user_id}_org:#{@org_id}") |> Repo.one()
      assert accesible_projects.value == proj_id
    end

    test "when runtime error occurs during the transaction", ctx do
      Support.Rbac.assign_org_role_by_name(@org_id, ctx.group.id, "BillingAdmin")

      proj_id = Ecto.UUID.generate()
      Support.Rbac.assign_project_role_by_name(@org_id, ctx.group.id, proj_id, "Reader")
      :ok = Group.add_to_group(ctx.group, ctx.user_id)

      with_mocks [
        {Rbac.Store.UserPermissions, [:passthrough], [add_permissions: fn _ -> raise "Error" end]}
      ] do
        try do
          {:error, :cache_refresh_error} = Group.remove_from_group(ctx.group, ctx.user_id)
        rescue
          e -> e
        end
      end

      org_permissions = Repo.UserPermissionsKeyValueStore |> where([up], up.key == ^"user:#{ctx.user_id}_org:#{@org_id}_project:*") |> Repo.one()
      assert org_permissions.value =~ "organization.view"

      project_permissions = Repo.UserPermissionsKeyValueStore |> where([up], up.key == ^"user:#{ctx.user_id}_org:#{@org_id}_project:#{proj_id}") |> Repo.one()
      assert project_permissions.value == "project.view"

      accesible_projects = Repo.ProjectAccessKeyValueStore |> where([pa], pa.key == ^"user:#{ctx.user_id}_org:#{@org_id}") |> Repo.one()
      assert accesible_projects.value == proj_id
    end
  end

  describe "destroy/1" do
    test "when group does not exist" do
      :ok = Group.destroy(Ecto.UUID.generate())
    end

    test "when group exists with user having both direct and group-assigned roles", %{user_id: user_id, group: group} do
      {:ok, rbi} = Rbac.RoleBindingIdentification.new(user_id: user_id, org_id: @org_id)
      Support.Factories.UserGroupBinding.insert(user_id: user_id, group_id: group.id)
      Support.Rbac.assign_org_role_by_name(@org_id, group.id, "BillingAdmin")
      permissions = Rbac.Store.UserPermissions.read_user_permissions(rbi)

      assert permissions =~ "organization.view"
      assert permissions =~ "organization.billing.manage"

      Group.destroy(group.id)

      permissions = Rbac.Store.UserPermissions.read_user_permissions(rbi)
      assert permissions =~ "organization.view"
      refute permissions =~ "organization.billing.manage"

      # Verify all related records are removed
      refute Repo.UserGroupBinding |> where([ugb], ugb.group_id == ^group.id) |> Repo.exists?()
      refute Repo.SubjectRoleBinding |> where([srb], srb.subject_id == ^group.id) |> Repo.exists?()
      refute Repo.Group |> where([g], g.id == ^group.id) |> Repo.exists?()
      refute Repo.Subject |> where([s], s.id == ^group.id) |> Repo.exists?()
    end
  end
end
