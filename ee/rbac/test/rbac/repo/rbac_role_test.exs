defmodule Rbac.Repo.RbacRole.Test do
  use Rbac.RepoCase, async: true

  alias Rbac.Repo.RbacRole

  @org_id "c47d7244-4d1f-4081-b919-d964b1019b0a"
  @non_existent_org_id "d3d8ca8a-b749-4e7a-b88c-2c8f3c7da78a"

  setup do
    {:ok, org_scope} = Support.Factories.Scope.insert("org_scope")
    {:ok, project_scope} = Support.Factories.Scope.insert("project_scope")

    {:ok, org_role} = Support.Factories.RbacRole.insert(org_id: @org_id, scope_id: org_scope.id)

    {:ok, project_role} =
      Support.Factories.RbacRole.insert(org_id: @org_id, scope_id: project_scope.id)

    state = %{
      :org_scope_id => org_scope.id,
      :project_scope_id => project_scope.id,
      :org_role_id => org_role.id,
      :project_role_id => project_role.id
    }

    {:ok, state}
  end

  describe "list_roles/1" do
    test "non-existent org_id given" do
      assert RbacRole.list_roles(@non_existent_org_id) == []
    end

    test "list role froma given org", state do
      org_roles_sorted =
        Enum.sort_by(RbacRole.list_roles(@org_id), fn org ->
          org.scope.scope_name
        end)

      assert length(org_roles_sorted) == 2
      assert Enum.at(org_roles_sorted, 0).id == state[:org_role_id]
      assert Enum.at(org_roles_sorted, 1).id == state[:project_role_id]
    end
  end

  describe "list_roles/2" do
    test "list org roles with organization scope", state do
      org_scope_roles = RbacRole.list_roles(@org_id, state.org_scope_id)

      assert length(org_scope_roles) == 1
      assert Enum.at(org_scope_roles, 0).scope.id == state.org_scope_id
    end

    test "list org roles with project scope", state do
      org_scope_roles = RbacRole.list_roles(@org_id, state.project_scope_id)

      assert length(org_scope_roles) == 1
      assert Enum.at(org_scope_roles, 0).scope.id == state.project_scope_id
    end
  end
end
