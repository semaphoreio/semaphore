defmodule Front.RBAC.RoleManagementTest do
  use ExUnit.Case, async: false
  @moduletag :rbac_roles
  @moduletag capture_log: true

  alias Front.RBAC.RoleManagement
  alias InternalApi.RBAC.Permission
  alias InternalApi.RBAC.Role
  alias InternalApi.RBAC.Scope

  alias Support.Stubs.DB

  setup_all do
    org_scope = DB.find_by(:scopes, :scope_name, "org_scope")
    org_permissions = DB.find_all_by(:permissions, :scope_id, org_scope.id)
    project_scope = DB.find_by(:scopes, :scope_name, "project_scope")
    project_permissions = DB.find_all_by(:permissions, :scope_id, project_scope.id)

    {:ok, org_permissions: org_permissions, project_permissions: project_permissions}
  end

  describe "list_existing_permissions/1" do
    test "for :organization scope lists all organization permissions", ctx do
      assert {:ok, permissions} = RoleManagement.list_existing_permissions(:organization)
      assert MapSet.new(permissions, & &1.id) == MapSet.new(ctx.org_permissions, & &1.id)
      assert Enum.all?(permissions, &(Scope.key(&1.scope) == :SCOPE_ORG))
    end

    test "for `organization` scope lists all organization permissions", ctx do
      assert {:ok, permissions} = RoleManagement.list_existing_permissions(:organization)
      assert MapSet.new(permissions, & &1.id) == MapSet.new(ctx.org_permissions, & &1.id)
      assert Enum.all?(permissions, &(Scope.key(&1.scope) == :SCOPE_ORG))
    end

    test "for :SCOPE_ORG scope lists all organization permissions", ctx do
      assert {:ok, permissions} = RoleManagement.list_existing_permissions(:SCOPE_ORG)
      assert MapSet.new(permissions, & &1.id) == MapSet.new(ctx.org_permissions, & &1.id)
      assert Enum.all?(permissions, &(Scope.key(&1.scope) == :SCOPE_ORG))
    end

    test "for 1 scope lists all organization permissions", ctx do
      assert {:ok, permissions} = RoleManagement.list_existing_permissions(1)
      assert MapSet.new(permissions, & &1.id) == MapSet.new(ctx.org_permissions, & &1.id)
      assert Enum.all?(permissions, &(Scope.key(&1.scope) == :SCOPE_ORG))
    end

    test "for :project scope lists all project permissions", ctx do
      assert {:ok, permissions} = RoleManagement.list_existing_permissions(:project)
      assert MapSet.new(permissions, & &1.id) == MapSet.new(ctx.project_permissions, & &1.id)
      assert Enum.all?(permissions, &(Scope.key(&1.scope) == :SCOPE_PROJECT))
    end

    test "for `project` scope lists all project permissions", ctx do
      assert {:ok, permissions} = RoleManagement.list_existing_permissions(:project)
      assert MapSet.new(permissions, & &1.id) == MapSet.new(ctx.project_permissions, & &1.id)
      assert Enum.all?(permissions, &(Scope.key(&1.scope) == :SCOPE_PROJECT))
    end

    test "for :SCOPE_PROJECT scope lists all project permissions", ctx do
      assert {:ok, permissions} = RoleManagement.list_existing_permissions(:SCOPE_PROJECT)
      assert MapSet.new(permissions, & &1.id) == MapSet.new(ctx.project_permissions, & &1.id)
      assert Enum.all?(permissions, &(Scope.key(&1.scope) == :SCOPE_PROJECT))
    end

    test "for 2 scope lists all project permissions", ctx do
      assert {:ok, permissions} = RoleManagement.list_existing_permissions(2)
      assert MapSet.new(permissions, & &1.id) == MapSet.new(ctx.project_permissions, & &1.id)
      assert Enum.all?(permissions, &(Scope.key(&1.scope) == :SCOPE_PROJECT))
    end

    test "for :unspecified scope lists all permissions", ctx do
      assert {:ok, permissions} = RoleManagement.list_existing_permissions(nil)

      assert MapSet.new(permissions, & &1.id) ==
               MapSet.new(ctx.org_permissions ++ ctx.project_permissions, & &1.id)

      assert Enum.all?(permissions, &(&1.scope > 0))
    end

    test "for nil scope lists all permissions", ctx do
      assert {:ok, permissions} = RoleManagement.list_existing_permissions(nil)

      assert MapSet.new(permissions, & &1.id) ==
               MapSet.new(ctx.org_permissions ++ ctx.project_permissions, & &1.id)

      assert Enum.all?(permissions, &(&1.scope > 0))
    end

    test "for :SCOPE_UNSPECIFIED scope lists all permissions", ctx do
      assert {:ok, permissions} = RoleManagement.list_existing_permissions(:SCOPE_UNSPECIFIED)

      assert MapSet.new(permissions, & &1.id) ==
               MapSet.new(ctx.org_permissions ++ ctx.project_permissions, & &1.id)

      assert Enum.all?(permissions, &(&1.scope > 0))
    end

    test "for 0 scope lists all permissions", ctx do
      assert {:ok, permissions} = RoleManagement.list_existing_permissions(0)

      assert MapSet.new(permissions, & &1.id) ==
               MapSet.new(ctx.org_permissions ++ ctx.project_permissions, & &1.id)

      assert Enum.all?(permissions, &(&1.scope > 0))
    end
  end

  describe "describe_role/2" do
    test "when role exists then describes the role" do
      %{org_id: org_id, id: role_id} = DB.all(:rbac_roles) |> List.first()
      assert {:ok, %Role{}} = RoleManagement.describe_role(org_id, role_id)
    end

    test "when role does not exist then returns error" do
      assert {:error, %GRPC.RPCError{status: 5, message: "Role not found"}} =
               RoleManagement.describe_role(UUID.uuid4(), UUID.uuid4())
    end
  end

  describe "modify_role/1" do
    test "when role and requester_id is valid then modifies the role" do
      assert {:ok, %{role_id: role_id}} = RoleManagement.modify_role(test_role(), UUID.uuid4())

      assert role = DB.find(:rbac_roles, role_id)
      if role, do: DB.delete(:rbac_roles, role.id)
    end

    test "when request fails then returns an error" do
      Support.Stubs.RBAC.Grpc.expect(:modify_role, fn ->
        raise GRPC.RPCError, status: :internal, message: "Unknown error"
      end)

      assert {:error, %GRPC.RPCError{status: 13, message: "Unknown error"}} =
               RoleManagement.modify_role(test_role(), UUID.uuid4())
    end

    test "when requester_id is nil then returns error" do
      assert {:error, :invalid_requester_id} = RoleManagement.modify_role(test_role(), nil)
    end

    test "when role is invalid then returns error" do
      assert {:error, :invalid_role} =
               RoleManagement.modify_role(%{id: "1", name: "admin"}, "requester_id")
    end
  end

  describe "destroy_role/3" do
    test "when role and requester_id is valid then modifies the role" do
      org_id = Support.Stubs.Organization.default_org_id()

      role =
        Support.Stubs.RBAC.add_role(
          org_id,
          "Test role",
          "project_scope",
          %{
            description: "Description of a custom project role",
            permissions: [
              "project.view",
              "project.delete",
              "project.access.view",
              "project.access.manage"
            ]
          }
        )

      assert {:ok, %{role_id: role_id}} =
               RoleManagement.destroy_role(org_id, UUID.uuid4(), role.id)

      assert role_id == role.id
      refute DB.find(:rbac_roles, role.id)
    end

    test "when request fails then returns an error" do
      Support.Stubs.RBAC.Grpc.expect(:destroy_role, fn ->
        raise GRPC.RPCError, status: :internal, message: "Unknown error"
      end)

      assert {:error, %GRPC.RPCError{status: 13, message: "Unknown error"}} =
               RoleManagement.destroy_role(UUID.uuid4(), UUID.uuid4(), UUID.uuid4())
    end
  end

  defp test_role do
    Role.new(
      id: UUID.uuid4(),
      name: "orgadmin",
      scope: Scope.value(:SCOPE_ORG),
      org_id: UUID.uuid4(),
      description: "admin role",
      rbac_permissions: [
        Permission.new(id: UUID.uuid4(), name: "create_user", scope: Scope.value(:SCOPE_ORG)),
        Permission.new(id: UUID.uuid4(), name: "delete_user", scope: Scope.value(:SCOPE_ORG))
      ]
    )
  end
end
