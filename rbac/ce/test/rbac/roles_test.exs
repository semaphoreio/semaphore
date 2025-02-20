defmodule Rbac.RolesTest do
  use ExUnit.Case
  alias Rbac.Roles

  describe "build_grpc_roles/0" do
    test "Check if the grpc roles are well formed" do
      roles = Roles.build_grpc_roles()

      assert length(roles) == 3

      [owner_role, admin_role, member_role] = roles

      assert owner_role.name == "Owner"
      assert owner_role.maps_to == nil
      assert member_role.inherited_role == nil
      assert(length(owner_role.permissions) > 0)
      assert(length(admin_role.permissions) > 0)

      assert owner_role.description =~
               "Owners have access to all functionalities within the organization and any of its projects."

      assert admin_role.name == "Admin"
      assert admin_role.maps_to == nil
      assert admin_role.inherited_role == nil
      assert(length(admin_role.permissions) > 0)

      assert admin_role.description =~
               "Admins can modify settings within the organization or any of its projects."

      assert member_role.name == "Member"
      assert member_role.maps_to == nil
      assert member_role.inherited_role == nil
      assert(length(member_role.permissions) > 0)

      assert member_role.description =~
               "Members can access the organization's homepage and the projects they are assigned to."
    end
  end
end
