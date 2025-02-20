defmodule Rbac.Store.Project.Test do
  use Rbac.RepoCase, async: true

  import Mock

  alias Rbac.Store, as: RS
  alias Rbac.Repo, as: RR

  describe ".update" do
    test "method should return project" do
      {:ok, project} =
        RS.Project.update(
          "ee2e6241-f30b-4892-a0d5-bd900b713430",
          "renderedtext/rbac",
          "8cbf8429-4230-4973-8d65-1e98b7d2ca64",
          "github",
          "1cbf8429-4230-4973-8d65-1e98b7d2ca64"
        )

      assert %RR.Project{
               org_id: "8cbf8429-4230-4973-8d65-1e98b7d2ca64",
               project_id: "ee2e6241-f30b-4892-a0d5-bd900b713430",
               repo_name: "renderedtext/rbac"
             } = project
    end

    test "insert project twice => method should return project" do
      {:ok, project} =
        RS.Project.update(
          "ee2e6241-f30b-4892-a0d5-bd900b713430",
          "renderedtext/rbac",
          "8cbf8429-4230-4973-8d65-1e98b7d2ca64",
          "github",
          "1cbf8429-4230-4973-8d65-1e98b7d2ca64"
        )

      assert %RR.Project{
               org_id: "8cbf8429-4230-4973-8d65-1e98b7d2ca64",
               project_id: "ee2e6241-f30b-4892-a0d5-bd900b713430",
               repo_name: "renderedtext/rbac",
               repository_id: "1cbf8429-4230-4973-8d65-1e98b7d2ca64"
             } = project

      {:ok, second_project} =
        RS.Project.update(
          "ee2e6241-f30b-4892-a0d5-bd900b713430",
          "renderedtext/rbac",
          "8cbf8429-4230-4973-8d65-1e98b7d2ca64",
          "github",
          "1cbf8429-4230-4973-8d65-1e98b7d2ca65"
        )

      assert second_project.id == project.id

      assert %RR.Project{
               org_id: "8cbf8429-4230-4973-8d65-1e98b7d2ca64",
               project_id: "ee2e6241-f30b-4892-a0d5-bd900b713430",
               repo_name: "renderedtext/rbac",
               repository_id: "1cbf8429-4230-4973-8d65-1e98b7d2ca65"
             } = second_project
    end
  end

  describe "membership/1 when rbac enabled" do
    test "User has access to a project" do
      org_id = Ecto.UUID.generate()
      user_id = Ecto.UUID.generate()
      project_1 = Ecto.UUID.generate()

      with_mocks [
        {Rbac.Store.UserPermissions, [],
         [
           read_user_permissions: fn _ -> "test_permision" end
         ]},
        {Rbac.Store.ProjectAccess, [],
         [
           get_list_of_projects: fn ^user_id, ^org_id -> [project_1] end
         ]},
        {Rbac.Store.Project, [:passthrough],
         [
           list_projects: fn _ -> {:ok, [project_1]} end
         ]}
      ] do
        assert Rbac.Store.Project.membership(user_id, org_id) == [project_1]
      end
    end

    test "User has access to all projects through org-lvl role" do
      org_id = Ecto.UUID.generate()
      user_id = Ecto.UUID.generate()
      project_1 = Ecto.UUID.generate()
      project_2 = Ecto.UUID.generate()

      with_mocks [
        {Rbac.Store.UserPermissions, [],
         [
           read_user_permissions: fn _ -> "test_permision,project.view,test_permission2" end
         ]},
        {Rbac.Store.Project, [:passthrough],
         [
           list_projects: fn _ ->
             {:ok, [project_1, project_2]}
           end
         ]}
      ] do
        assert Rbac.Store.Project.membership(user_id, org_id) == [project_1, project_2]
        assert_called_exactly(Rbac.Store.Project.list_projects(org_id), 1)
      end
    end
  end
end
