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

  describe "modify_metadata/3" do
    test "when new name is already taken", ctx do
      {:ok, new_group} = Support.Factories.Group.insert(org_id: @org_id)
      {:error, :name_taken} = Group.modify_metadata(ctx.group.id, @org_id, new_group.name, "")

      assert match?({:ok, _}, Group.fetch_group_by_name(ctx.group.name, @org_id))
    end

    test "when name is changed", ctx do
      new_name = "new_group_name"
      {:ok, _} = Group.modify_metadata(ctx.group.id, @org_id, new_name, "")
      {:ok, group} = Group.fetch_group_by_name(new_name, @org_id)

      assert group.description == ctx.group.description
    end

    test "when description is changed", ctx do
      new_description = "new_description"
      {:ok, _} = Group.modify_metadata(ctx.group.id, @org_id, "", new_description)
      {:ok, group} = Group.fetch_group_by_name(ctx.group.name, @org_id)

      assert group.description == new_description
    end
  end

  describe "create_group/3" do
    test "when group name already exists", ctx do
      {:error, :name_taken} = Group.create_group(ctx.group, ctx.group.org_id, ctx.user_id)
    end

    test "when group data is not provided", ctx do
      {:error, :group_data_not_provided} = Group.create_group(nil, ctx.group.org_id, ctx.user_id)
    end

    test "when group is created successfully", ctx do
      new_group = %{name: "unique_group_name", description: "desc"}
      {:ok, group} = Group.create_group(new_group, ctx.group.org_id, ctx.user_id)

      Repo.Group
      |> where([g], g.org_id == ^ctx.group.org_id and g.description == ^new_group.description)
      |> Repo.exists?()
      |> assert

      Repo.Subject
      |> where([s], s.id == ^group.id and s.name == ^new_group.name)
      |> Repo.exists?()
      |> assert
    end

    test "when transaction fails during group creation", ctx do
      new_group = %{name: "fail_group", description: "desc"}

      mocked_insert = fn struct, opts ->
        if struct.data == %Repo.Group{} do
          {:error, :insert_group_failed}
        else
          :meck.passthrough([struct, opts])
        end
      end

      with_mock Repo, [:passthrough], insert: mocked_insert do
        {:error, :insert_group_failed} = Group.create_group(new_group, @org_id, ctx.user_id)

        Repo.Subject |> where([s], s.name == ^new_group.name) |> Repo.exists?() |> refute
      end
    end
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

      org_permissions = fetch_permissions(ctx.user_id, @org_id)
      assert org_permissions =~ "organization.view"
      assert org_permissions =~ "organization.billing.manage"

      project_permissions = fetch_permissions(ctx.user_id, @org_id, proj_id)
      assert project_permissions =~ "project.view"

      accesible_projects = fetch_accessible_projects(ctx.user_id, @org_id)
      assert accesible_projects == [proj_id]
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

      org_permissions = fetch_permissions(ctx.user_id, @org_id)
      assert org_permissions =~ "organization.view"
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

      org_permissions = fetch_permissions(ctx.user_id, @org_id)
      assert org_permissions =~ "organization.view"
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

      org_permissions = fetch_permissions(ctx.user_id, @org_id)
      assert org_permissions =~ "organization.view"

      refute fetch_permissions(ctx.user_id, @org_id, proj_id) =~ "project.view"
      assert fetch_accessible_projects(ctx.user_id, @org_id) == []
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

      org_permissions = fetch_permissions(ctx.user_id, @org_id)
      assert org_permissions =~ "organization.view"
      assert org_permissions =~ "organization.billing.manage"

      project_permissions = fetch_permissions(ctx.user_id, @org_id, proj_id)
      assert project_permissions =~ "project.view"

      accesible_projects = fetch_accessible_projects(ctx.user_id, @org_id)
      assert accesible_projects == [proj_id]
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

      org_permissions = fetch_permissions(ctx.user_id, @org_id)
      assert org_permissions =~ "organization.view"

      project_permissions = fetch_permissions(ctx.user_id, @org_id, proj_id)
      assert project_permissions =~ "project.view"

      accesible_projects = fetch_accessible_projects(ctx.user_id, @org_id)
      assert accesible_projects == [proj_id]
    end
  end

  describe "destroy/1" do
    test "when group does not exist" do
      :ok = Group.destroy(Ecto.UUID.generate())
    end

    test "when group exists with user having both direct and group-assigned roles", %{
      user_id: user_id,
      group: group
    } do
      {:ok, proj1} = Support.Factories.Project.insert(org_id: @org_id)
      {:ok, proj2} = Support.Factories.Project.insert(org_id: @org_id)

      Support.Factories.UserGroupBinding.insert(user_id: user_id, group_id: group.id)
      Support.Rbac.assign_project_role_by_name(@org_id, user_id, proj1.id, "Reader")

      Support.Rbac.assign_org_role_by_name(@org_id, group.id, "BillingAdmin")
      Support.Rbac.assign_project_role_by_name(@org_id, group.id, proj2.id, "Reader")

      permissions = fetch_permissions(user_id, @org_id)
      assert permissions =~ "organization.view"
      assert permissions =~ "organization.billing.manage"

      proj1_permissions = fetch_permissions(user_id, @org_id, proj1.id)
      proj2_permissions = fetch_permissions(user_id, @org_id, proj2.id)
      assert proj1_permissions =~ "project.view"
      assert proj2_permissions =~ "project.view"

      accessible_projects = fetch_accessible_projects(user_id, @org_id)
      assert Enum.sort(accessible_projects) == Enum.sort([proj1.id, proj2.id])

      Group.destroy(group.id)

      permissions = fetch_permissions(user_id, @org_id)
      assert permissions =~ "organization.view"
      refute permissions =~ "organization.billing.manage"

      accessible_projects = fetch_accessible_projects(user_id, @org_id)
      assert accessible_projects == [proj1.id]

      proj1_permissions = fetch_permissions(user_id, @org_id, proj1.id)
      proj2_permissions = fetch_permissions(user_id, @org_id, proj2.id)
      assert proj1_permissions =~ "project.view"
      refute proj2_permissions =~ "project.view"

      # Verify all related records are removed
      refute Repo.UserGroupBinding |> where([ugb], ugb.group_id == ^group.id) |> Repo.exists?()
      refute Repo.Group |> where([g], g.id == ^group.id) |> Repo.exists?()
      refute Repo.Subject |> where([s], s.id == ^group.id) |> Repo.exists?()

      refute Repo.SubjectRoleBinding
             |> where([srb], srb.subject_id == ^group.id)
             |> Repo.exists?()
    end

    test "When something breaks during the transaction", %{
      user_id: user_id,
      group: group
    } do
      {:ok, proj} = Support.Factories.Project.insert(org_id: @org_id)

      Support.Factories.UserGroupBinding.insert(user_id: user_id, group_id: group.id)
      Support.Rbac.assign_org_role_by_name(@org_id, group.id, "BillingAdmin")
      Support.Rbac.assign_project_role_by_name(@org_id, group.id, proj.id, "Reader")

      with_mocks [
        {Rbac.Store.UserPermissions, [:passthrough], [add_permissions: fn _ -> :error end]}
      ] do
        {:error, :cache_refresh_error} = Group.destroy(group.id)
      end

      permissions = fetch_permissions(user_id, @org_id)
      assert permissions =~ "organization.view"
      assert permissions =~ "organization.billing.manage"

      proj_permissions = fetch_permissions(user_id, @org_id, proj.id)
      assert proj_permissions =~ "project.view"

      accessible_projects = fetch_accessible_projects(user_id, @org_id)
      assert accessible_projects == [proj.id]

      assert Repo.UserGroupBinding |> where([ugb], ugb.group_id == ^group.id) |> Repo.exists?()
      assert Repo.Group |> where([g], g.id == ^group.id) |> Repo.exists?()
      assert Repo.Subject |> where([s], s.id == ^group.id) |> Repo.exists?()

      assert Repo.SubjectRoleBinding
             |> where([srb], srb.subject_id == ^group.id)
             |> Repo.exists?()
    end
  end

  ###
  ### Helper functions
  ###

  defp fetch_permissions(user_id, org_id, project_id \\ nil) do
    alias Rbac.RoleBindingIdentification, as: RBI
    {:ok, rbi} = RBI.new(user_id: user_id, org_id: org_id, project_id: project_id)
    Rbac.Store.UserPermissions.read_user_permissions(rbi)
  end

  def fetch_accessible_projects(user_id, org_id) do
    Rbac.Store.ProjectAccess.get_list_of_projects(user_id, org_id)
  end
end
