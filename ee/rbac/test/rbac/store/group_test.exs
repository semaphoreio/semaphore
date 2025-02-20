defmodule Rbac.Store.Group.Test do
  use Rbac.RepoCase, async: true

  alias Rbac.Store.Group

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
      group = %Rbac.Repo.Group{id: Ecto.UUID.generate(), org_id: Ecto.UUID.generate()}
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

      org_permissions =
        Rbac.Repo.UserPermissionsKeyValueStore
        |> where([up], up.key == ^"user:#{ctx.user_id}_org:#{@org_id}_project:*")
        |> Rbac.Repo.one()

      assert org_permissions.value =~ "organization.view"
      assert org_permissions.value =~ "organization.billing.manage"

      project_permissions =
        Rbac.Repo.UserPermissionsKeyValueStore
        |> where([up], up.key == ^"user:#{ctx.user_id}_org:#{@org_id}_project:#{proj_id}")
        |> Rbac.Repo.one()

      assert project_permissions.value == "project.view"

      accesible_projects =
        Rbac.Repo.ProjectAccessKeyValueStore
        |> where([pa], pa.key == ^"user:#{ctx.user_id}_org:#{@org_id}")
        |> Rbac.Repo.one()

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

      org_permissions =
        Rbac.Repo.UserPermissionsKeyValueStore
        |> where([up], up.key == ^"user:#{ctx.user_id}_org:#{@org_id}_project:*")
        |> Rbac.Repo.one()

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

      org_permissions =
        Rbac.Repo.UserPermissionsKeyValueStore
        |> where([up], up.key == ^"user:#{ctx.user_id}_org:#{@org_id}_project:*")
        |> Rbac.Repo.one()

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

      org_permissions =
        Rbac.Repo.UserPermissionsKeyValueStore
        |> where([up], up.key == ^"user:#{ctx.user_id}_org:#{@org_id}_project:*")
        |> Rbac.Repo.one()

      assert org_permissions.value =~ "organization.view"

      refute Rbac.Repo.UserPermissionsKeyValueStore
             |> where([up], up.key == ^"user:#{ctx.user_id}_org:#{@org_id}_project:#{proj_id}")
             |> Rbac.Repo.exists?()

      refute Rbac.Repo.ProjectAccessKeyValueStore
             |> where([pa], pa.key == ^"user:#{ctx.user_id}_org:#{@org_id}")
             |> Rbac.Repo.exists?()
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

      org_permissions =
        Rbac.Repo.UserPermissionsKeyValueStore
        |> where([up], up.key == ^"user:#{ctx.user_id}_org:#{@org_id}_project:*")
        |> Rbac.Repo.one()

      assert org_permissions.value =~ "organization.view"
      assert org_permissions.value =~ "organization.billing.manage"

      project_permissions =
        Rbac.Repo.UserPermissionsKeyValueStore
        |> where([up], up.key == ^"user:#{ctx.user_id}_org:#{@org_id}_project:#{proj_id}")
        |> Rbac.Repo.one()

      assert project_permissions.value == "project.view"

      accesible_projects =
        Rbac.Repo.ProjectAccessKeyValueStore
        |> where([pa], pa.key == ^"user:#{ctx.user_id}_org:#{@org_id}")
        |> Rbac.Repo.one()

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

      org_permissions =
        Rbac.Repo.UserPermissionsKeyValueStore
        |> where([up], up.key == ^"user:#{ctx.user_id}_org:#{@org_id}_project:*")
        |> Rbac.Repo.one()

      assert org_permissions.value =~ "organization.view"

      project_permissions =
        Rbac.Repo.UserPermissionsKeyValueStore
        |> where([up], up.key == ^"user:#{ctx.user_id}_org:#{@org_id}_project:#{proj_id}")
        |> Rbac.Repo.one()

      assert project_permissions.value == "project.view"

      accesible_projects =
        Rbac.Repo.ProjectAccessKeyValueStore
        |> where([pa], pa.key == ^"user:#{ctx.user_id}_org:#{@org_id}")
        |> Rbac.Repo.one()

      assert accesible_projects.value == proj_id
    end
  end
end
