defmodule Guard.Api.ProjectTest do
  use ExUnit.Case, async: true
  import Mock

  alias Guard.Api.Project

  describe "destroy_all_projects_by_org_id/1" do
    test "successfully deletes all projects for a given org_id" do
      org_id = "valid_org_id"
      user_id = "valid_user_id"

      with_mock InternalApi.Projecthub.ProjectService.Stub,
        list: fn _channel, _req, _opts ->
          {:ok,
           %{
             metadata: %{status: %{code: 0}},
             projects: [
               %{metadata: %{id: 1, org_id: org_id, owner_id: user_id}},
               %{metadata: %{id: 2, org_id: org_id, owner_id: user_id}}
             ]
           }}
        end,
        destroy: fn _channel, %{id: _project_id, metadata: _metadata}, _opts ->
          {:ok, %{metadata: %{status: %{code: 0}}}}
        end do
        assert Project.destroy_all_projects_by_org_id(org_id) == :ok
      end
    end

    test "returns error when org_id is invalid" do
      assert {:error, "Invalid org_id"} == Project.destroy_all_projects_by_org_id("")
    end

    test "handles failure on project list retrieval" do
      org_id = "failing_org_id"

      with_mock InternalApi.Projecthub.ProjectService.Stub,
        list: fn _channel, _req, _opts ->
          {:error, "Failed to retrieve projects"}
        end do
        assert {:error, "Failed to retrieve projects for org #{org_id}"} ==
                 Project.destroy_all_projects_by_org_id(org_id)
      end
    end
  end

  describe "user_has_any_project?/1" do
    test "returns true when user has at least one project" do
      user_id = "user_with_projects"

      with_mock InternalApi.Projecthub.ProjectService.Stub,
        list: fn _channel, _req, _opts ->
          {:ok,
           %{
             metadata: %{status: %{code: 0}},
             projects: [
               %{metadata: %{id: 1, org_id: "org_id", owner_id: user_id}}
             ]
           }}
        end do
        assert Project.user_has_any_project?(user_id) == true
      end
    end

    test "returns false when user has no projects" do
      user_id = "user_without_projects"

      with_mock InternalApi.Projecthub.ProjectService.Stub,
        list: fn _channel, _req, _opts ->
          {:ok,
           %{
             metadata: %{status: %{code: 0}},
             projects: []
           }}
        end do
        assert Project.user_has_any_project?(user_id) == false
      end
    end

    test "If communication with projecthub fails, we consider that user does own projects" do
      user_id = "user_with_error"

      with_mock InternalApi.Projecthub.ProjectService.Stub,
        list: fn _channel, _req, _opts ->
          {:error, "Failed to retrieve projects"}
        end do
        assert Project.user_has_any_project?(user_id)
      end
    end
  end
end
