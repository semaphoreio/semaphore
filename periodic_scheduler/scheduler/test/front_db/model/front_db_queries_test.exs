defmodule Scheduler.FrontDB.Model.FrontDBQueries.Test do
  use ExUnit.Case

  alias Scheduler.FrontDB.Model.FrontDBQueries

  setup do
    Test.Helpers.truncate_db()
    params = Test.Helpers.seed_front_db()
    {:ok, params}
  end

  test "get_project_id() return project_id or 'Not Fount' error", ctx do
    assert {:ok, ctx.pr_id} == FrontDBQueries.get_project_id(ctx.org_id, "Project 1")

    assert {:error, "Project with name 'Non existent' not found."} ==
             FrontDBQueries.get_project_id(ctx.org_id, "Non existent")
  end

  test "get_project_name() return project name or 'Not Found' error", ctx do
    assert {:ok, "Project 1"} == FrontDBQueries.get_project_name(ctx.org_id, ctx.pr_id)

    project_id = UUID.uuid4()

    assert {:error, "Project with ID '#{project_id}' not found."} ==
             FrontDBQueries.get_project_name(ctx.org_id, project_id)
  end

  test "hook_exists?() returns true when there is a hook for given branch", ctx do
    assert {:ok, true} = FrontDBQueries.hook_exists?(ctx.pr_id, "master")
  end

  test "hook_exists?() returns false when there are no hooks for given branch or project", ctx do
    assert {:ok, false} = FrontDBQueries.hook_exists?(ctx.pr_id, "non-existent")
    assert {:ok, false} = FrontDBQueries.hook_exists?(UUID.uuid4(), "master")
  end

  test "get_hook() returns valid data when hook exists for given branch", ctx do
    assert {:ok, expected_hook_data(ctx)} == FrontDBQueries.get_hook(ctx.pr_id, "master")
  end

  defp expected_hook_data(ctx) do
    %{
      repo: %{
        owner: "renderedtext",
        repo_name: "test_repo",
        branch_name: "master",
        payload: "{\"after\":\"#{ctx.commit_sha}\",\"head_commit\":{\"id\":\"\"}}"
      },
      auth: %{
        access_token: "access_token value"
      },
      project_id: ctx.pr_id,
      branch_id: ctx.br_id,
      hook_id: ctx.wf_id,
      label: "master"
    }
  end

  test "get_hook() returns error when there are no hooks for given branch or project", ctx do
    assert {:error, "Hook for project '#{ctx.pr_id}' on branch 'non-existent' not found."} ==
             FrontDBQueries.get_hook(ctx.pr_id, "non-existent")

    id = UUID.uuid4()

    assert {:error, "Hook for project '#{id}' on branch 'master' not found."} ==
             FrontDBQueries.get_hook(id, "master")
  end
end
