defmodule FrontWeb.Views.RolesViewTest do
  use ExUnit.Case, async: true
  alias InternalApi.RBAC.Role
  alias InternalApi.RBAC.Scope

  setup_all do
    {:ok,
     roles: [
       Role.new(id: "or1", name: "org_role_1", scope: Scope.value(:SCOPE_ORG)),
       Role.new(id: "or2", name: "org_role_2", scope: Scope.value(:SCOPE_ORG)),
       Role.new(id: "pr1", name: "project_role_1", scope: Scope.value(:SCOPE_PROJECT)),
       Role.new(id: "pr2", name: "project_role_2", scope: Scope.value(:SCOPE_PROJECT))
     ]}
  end

  describe "organization_roles/1" do
    test "filters for organization roles", ctx do
      assert FrontWeb.RolesView.organization_roles(ctx.roles) == [
               Role.new(id: "or1", name: "org_role_1", scope: Scope.value(:SCOPE_ORG)),
               Role.new(id: "or2", name: "org_role_2", scope: Scope.value(:SCOPE_ORG))
             ]
    end
  end

  describe "project_roles/1" do
    test "filters for project roles", ctx do
      assert FrontWeb.RolesView.project_roles(ctx.roles) == [
               Role.new(id: "pr1", name: "project_role_1", scope: Scope.value(:SCOPE_PROJECT)),
               Role.new(id: "pr2", name: "project_role_2", scope: Scope.value(:SCOPE_PROJECT))
             ]
    end
  end

  describe "role_mapping_options/1" do
    test "uses project roles to form options", ctx do
      assert FrontWeb.RolesView.role_mapping_options(ctx.roles) == [
               {"project_role_1", "pr1"},
               {"project_role_2", "pr2"}
             ]
    end
  end

  describe "number_of_permissions/1" do
    test "for 0 permissions displays `No permissions`" do
      assert FrontWeb.RolesView.number_of_permissions([]) == "No permissions"
    end

    test "for 1 permission displays `1 permission`" do
      assert FrontWeb.RolesView.number_of_permissions([%{id: UUID.uuid4()}]) == "1 permission"
    end

    test "for more than 1 permission displays `n permissions`" do
      permissions = Enum.map(1..3, fn _ -> %{id: UUID.uuid4()} end)
      assert FrontWeb.RolesView.number_of_permissions(permissions) == "3 permissions"
    end
  end
end
