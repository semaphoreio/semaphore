defmodule Rbac.Store.RbacRole.Test do
  use Rbac.RepoCase, async: true

  import Mock
  alias Rbac.Store.RbacRole, as: Role
  alias Rbac.Repo

  @org_id Ecto.UUID.generate()

  setup do
    Support.Factories.Scope.insert("org_scope")
    Support.Factories.Scope.insert("project_scope")
    Repo.Permission.insert_default_permissions()

    :ok
  end

  describe "create_or_update/2" do
    # ========================== VALIDATE DATA TESTS =========================
    test "When some passed permissions don't exist" do
      random_id = Ecto.UUID.generate()
      msg = "Some permissions do not exist"
      {:error, ^msg} = Role.create_or_update(create_role_params(permission_ids: [random_id]))
    end

    test "When new role scope and permission scopes don't match" do
      msg = "Scope of some permissions does not match the scope of the role"
      permission_id = Repo.Permission.get_permission_id("project.view")
      {:error, ^msg} = Role.create_or_update(create_role_params(permission_ids: [permission_id]))
    end

    test "when maps_to role does not exist" do
      random_id = Ecto.UUID.generate()
      msg = "Role passed as 'maps_to' does not exist"
      {:error, ^msg} = Role.create_or_update(create_role_params(maps_to_role_id: random_id))
    end

    test "when maps_to role belongs to another organizaztion" do
      other_org_id = Ecto.UUID.generate()
      Support.Rbac.create_org_roles(other_org_id)
      {:ok, role} = Repo.RbacRole.get_role_by_name("Member", "org_scope", other_org_id)

      msg = "The 'maps_to' role does not belog to the same organization as the parent role"
      {:error, ^msg} = Role.create_or_update(create_role_params(maps_to_role_id: role.id))
    end

    test "when maps_to role is organization scope" do
      Support.Rbac.create_org_roles(@org_id)
      {:ok, role} = Repo.RbacRole.get_role_by_name("Member", "org_scope", @org_id)

      msg = "Organization level roles can not map to another organization level role"
      {:error, ^msg} = Role.create_or_update(create_role_params(maps_to_role_id: role.id))
    end

    test "when user tries to assign a maps_to role to the project level role" do
      Support.Rbac.create_project_roles(@org_id)
      {:ok, role} = Repo.RbacRole.get_role_by_name("Reader", "project_scope", @org_id)

      msg = "Only organization level roles can have a 'map_to' role"

      {:error, ^msg} =
        Role.create_or_update(
          create_role_params(scope: "project_scope", maps_to_role_id: role.id)
        )
    end

    test "when inherited_role doesn't exist" do
      random_id = Ecto.UUID.generate()
      msg = "Role passed as 'inherited_role' does not exist"
      {:error, ^msg} = Role.create_or_update(create_role_params(inherited_role_id: random_id))
    end

    test "when inherited_role does not belong to the same org as parent role" do
      other_org_id = Ecto.UUID.generate()
      Support.Rbac.create_org_roles(other_org_id)
      {:ok, role} = Repo.RbacRole.get_role_by_name("Member", "org_scope", other_org_id)

      msg = "The 'inherited_role' doesn't belog to the same organization as the parent role"
      {:error, ^msg} = Role.create_or_update(create_role_params(inherited_role_id: role.id))
    end

    test "when inherited_role scope does not match parent role's scope" do
      Support.Rbac.create_project_roles(@org_id)
      {:ok, role} = Repo.RbacRole.get_role_by_name("Reader", "project_scope", @org_id)

      msg = "Inherited role must have the same scope as the parent role"
      {:error, ^msg} = Role.create_or_update(create_role_params(inherited_role_id: role.id))
    end

    test "when required role fields are not passed" do
      invalid_roles = [
        create_role_params(name: ""),
        create_role_params(org_id: "")
      ]

      msg = "Some required fields are misssing"
      Enum.each(invalid_roles, &({:error, ^msg} = Role.create_or_update(&1)))
    end

    # ========================================================================

    test "successfully create a role that does not inherit nor map to other roles" do
      with_mocks [{Rbac.RoleBindingIdentification, [:passthrough], [new: fn _ -> :ok end]}] do
        {:ok, role} = Role.create_or_update(create_role_params(scope: "project_scope"))
        assert role.name == "Test"
        assert role.org_id == @org_id
        assert role.description == "test desc"
        assert role.scope_id == Repo.Scope.get_scope_by_name("project_scope").id
        assert [%Repo.Permission{name: "project.view"}] = role.permissions
        assert role.editable

        # Since the new role is being created, dont recalculate any permissions
        assert_not_called(Rbac.RoleBindingIdentification.new(:_))
      end
    end

    test "successfully create a role that both inherits and maps to other roles" do
      Support.Rbac.create_org_roles(@org_id)
      Support.Rbac.create_project_roles(@org_id)
      {:ok, org_member} = Repo.RbacRole.get_role_by_name("Member", "org_scope", @org_id)
      {:ok, proj_reader} = Repo.RbacRole.get_role_by_name("Reader", "project_scope", @org_id)

      {:ok, role} =
        Role.create_or_update(
          create_role_params(maps_to_role_id: proj_reader.id, inherited_role_id: org_member.id)
        )

      assert role.inherited_role.name == "Member"
      assert role.proj_role_mapping.name == "Reader"
      assert role.editable
    end

    test "If some database error occurres, roll back everything" do
      with_mocks [{Rbac.Repo, [:passthrough], [preload: fn _, _ -> raise "oops" end]}] do
        assert catch_error(Role.create_or_update(create_role_params()))
        assert {:error, :not_found} = Repo.RbacRole.get_role_by_name("Test", "org_scope", @org_id)
      end
    end

    test "Try to update role that does not exist yet" do
      role_params = create_role_params(id: Ecto.UUID.generate())

      msg = "The role does not exist."
      assert {:error, ^msg} = Role.create_or_update(role_params)
    end

    test "Default roles can not be edited" do
      Support.Rbac.create_org_roles(@org_id)
      {:ok, role} = Repo.RbacRole.get_role_by_name("Member", "org_scope", @org_id)
      msg = "This is the default role and it can not be edited nor deleted."
      {:error, ^msg} = Role.create_or_update(create_role_params(id: role.id, name: "Name"))
    end

    test "successfully update Admin role" do
      {:ok, user} = Support.Factories.RbacUser.insert()
      Support.Rbac.create_org_roles(@org_id)
      Support.Rbac.create_project_roles(@org_id)
      Support.Rbac.assign_org_role_by_name(@org_id, user.id, "Admin")

      {:ok, org_member} = Repo.RbacRole.get_role_by_name("Member", "org_scope", @org_id)
      {:ok, org_admin} = Repo.RbacRole.get_role_by_name("Admin", "org_scope", @org_id)
      {:ok, proj_reader} = Repo.RbacRole.get_role_by_name("Reader", "project_scope", @org_id)

      org_admin |> Repo.RbacRole.changeset(%{editable: true}) |> Repo.update()
      new_permissions = [Repo.Permission.get_permission_id("organization.notifications.manage")]

      {:ok, updated_role} =
        Role.create_or_update(
          create_role_params(
            id: org_admin.id,
            name: "Admin2",
            permission_ids: new_permissions,
            maps_to_role_id: proj_reader.id,
            inherited_role_id: org_member.id
          )
        )

      assert updated_role.id == org_admin.id
      assert updated_role.name == "Admin2"
      assert updated_role.inherited_role.name == "Member"
      assert updated_role.proj_role_mapping.name == "Reader"

      expected_permissions = ["organization.view", "organization.notifications.manage"]
      assert updated_role.permissions |> Enum.map(& &1.name) == expected_permissions

      # Make sure user's permissions have been updated
      {:ok, rbi} = Rbac.RoleBindingIdentification.new(user_id: user.id, org_id: @org_id)
      permissions = Rbac.Store.UserPermissions.read_user_permissions(rbi)
      assert permissions =~ "organization.notifications.manage"
      assert permissions =~ "organization.view"
      assert permissions =~ "project.view"
    end

    defp create_role_params(opts \\ []) do
      defaults = [
        name: "Test",
        description: "test desc",
        scope: "org_scope",
        org_id: @org_id,
        mapst_to_role_id: nil,
        inherited_role_id: nil,
        permission_ids: []
      ]

      opts = Keyword.merge(defaults, opts)
      scope_id = Repo.Scope.get_scope_by_name(opts[:scope]).id

      opts |> Keyword.put(:scope_id, scope_id) |> Keyword.delete(:scope)
    end
  end

  describe "delete/2" do
    test "role does not exist within the given org" do
      Support.Rbac.create_org_roles(@org_id)
      {:ok, role} = Repo.RbacRole.get_role_by_name("Member", "org_scope", @org_id)
      msg = "The role does not exist."
      {:error, ^msg} = Role.delete_role(role.id, Ecto.UUID.generate())
    end

    test "role is not editable" do
      Support.Rbac.create_org_roles(@org_id)
      {:ok, role} = Repo.RbacRole.get_role_by_name("Member", "org_scope", @org_id)

      msg = "This is the default role and it can not be edited nor deleted."
      {:error, ^msg} = Role.delete_role(role.id, @org_id)
    end

    test "role exists, but there is a group which has it assigned" do
      Support.Rbac.create_org_roles(@org_id)
      {:ok, role} = Repo.RbacRole.get_role_by_name("Member", "org_scope", @org_id)
      role |> Repo.RbacRole.changeset(%{editable: true}) |> Repo.update()

      {:ok, group} = Support.Factories.Group.insert(org_id: @org_id)
      Support.Rbac.assign_org_role_by_name(@org_id, group.id, "Member")

      msg = "The Member role cannot be deleted because it is currently assigned to a user."
      {:error, ^msg} = Role.delete_role(role.id, @org_id)
    end

    test "Some other role maps to the role we are trying to delete" do
      Support.Rbac.create_org_roles(@org_id)
      Support.Rbac.create_project_roles(@org_id)

      {:ok, member} = Repo.RbacRole.get_role_by_name("Member", "org_scope", @org_id)
      {:ok, reader} = Repo.RbacRole.get_role_by_name("Reader", "project_scope", @org_id)
      reader |> Repo.RbacRole.changeset(%{editable: true}) |> Repo.update()

      %Repo.OrgRoleToProjRoleMapping{org_role_id: member.id, proj_role_id: reader.id}
      |> Repo.insert()

      msg =
        "The Reader role cannot be deleted because it is used for defining some organization level roles."

      {:error, ^msg} = Role.delete_role(reader.id, @org_id)
    end

    test "Some other role inherits the role we are trying to delete" do
      Support.Rbac.create_org_roles(@org_id)
      Support.Rbac.create_project_roles(@org_id)

      {:ok, admin} = Repo.RbacRole.get_role_by_name("Admin", "org_scope", @org_id)
      {:ok, member} = Repo.RbacRole.get_role_by_name("Member", "org_scope", @org_id)
      member |> Repo.RbacRole.changeset(%{editable: true}) |> Repo.update()

      %Repo.RoleInheritance{inheriting_role_id: admin.id, inherited_role_id: member.id}
      |> Repo.insert()

      msg = "The Member role cannot be deleted because it is inherited by other roles."
      {:error, ^msg} = Role.delete_role(member.id, @org_id)
    end

    test "role is successfully deleted" do
      Support.Rbac.create_org_roles(@org_id)
      {:ok, role} = Repo.RbacRole.get_role_by_name("Member", "org_scope", @org_id)
      role |> Repo.RbacRole.changeset(%{editable: true}) |> Repo.update()

      {:ok, %Repo.RbacRole{} = struct} = Role.delete_role(role.id, @org_id)
      assert struct.id == role.id
      assert is_nil(Repo.RbacRole.get_role_by_id(role.id))
    end
  end

  describe "create_default_roles_for_organization/1" do
    test "successful creation" do
      import Ecto.Query, only: [where: 3]
      Role.create_default_roles_for_organization(@org_id)

      assert Repo.aggregate(Repo.RbacRole, :count, :id) == 6
      assert Repo.aggregate(Repo.RepoToRoleMapping, :count, :org_id) == 1
      assert Repo.aggregate(Repo.OrgRoleToProjRoleMapping, :count, :org_role_id) == 2
      # None of the default roles should be editable
      refute Repo.exists?(Repo.RbacRole |> where([r], r.editable == true))
    end
  end
end
