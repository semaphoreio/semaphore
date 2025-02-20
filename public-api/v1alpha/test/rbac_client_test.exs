defmodule PipelinesAPI.RBACClient.Test do
  use ExUnit.Case

  alias Support.Stubs
  alias PipelinesAPI.RBACClient

  @default_org_id "92be62c2-9cf4-4dad-b168-d6efa6aa5e21"
  @default_project_id "92be1234-1234-4234-8234-123456789012"
  @null_org_id "00000000-0000-0000-0000-000000000000"

  describe "test RBACClient list project members" do
    test "returns user error when project id is missing" do
      assert {:error,
              {:user,
               "organization id and project id are required to make list project members request"}} ==
               RBACClient.list_project_members(%{org_id: "123"})
    end

    test "returns user error when organization id is missing" do
      assert {:error,
              {:user,
               "organization id and project id are required to make list project members request"}} ==
               RBACClient.list_project_members(%{project_id: "123"})
    end

    test "returns list of members for the organization and project" do
      assert {:ok, members} =
               RBACClient.list_project_members(%{
                 org_id: @default_org_id,
                 project_id: @default_project_id
               })

      Stubs.build_shared_factories()

      assert [
               %{
                 subject_role_bindings: [%{role: %{name: "Member"}}],
                 subject: %{display_name: "Milica Nerlovic"}
               }
             ] = members
    end

    test "returns empty list of members for the organization and project" do
      assert {:ok, members} =
               RBACClient.list_project_members(%{
                 org_id: "some-org-id",
                 project_id: "some-project-id"
               })

      assert length(members) == 0
    end
  end

  describe "test RBACClient list organization project scope roles" do
    test "returns user error when organization id is missing" do
      assert {:error, {:user, "organization id is required to make list roles request"}} ==
               RBACClient.list_project_scope_roles(%{})
    end

    test "returns list of project scope roles for the organization" do
      assert {:ok, roles} = RBACClient.list_project_scope_roles(%{org_id: @null_org_id})
      assert length(roles) == 2
    end
  end
end
