defmodule HooksProcessor.Hooks.Payload.GitlabTest do
  use ExUnit.Case
  require Logger

  alias HooksProcessor.Hooks.Payload.Gitlab, as: GitlabPayload
  alias Support.GitlabHooks

  test "hook_type() returns proper hook type for all types of hooks" do
    # Branch

    branch_hooks = [
      GitlabHooks.push_new_branch_with_commits(),
      GitlabHooks.push_new_branch_no_commits(),
      GitlabHooks.push_commit(),
      GitlabHooks.push_delete_branch()
    ]

    branch_hooks
    |> Enum.each(fn hook ->
      assert GitlabPayload.hook_type(hook) == "push"
    end)

    # Tag

    tag_hook = GitlabHooks.tag_push()

    assert GitlabPayload.hook_type(tag_hook) == "tag_push"

    # PR

    pr_hooks = [
      GitlabHooks.merge_request_open(),
      GitlabHooks.merge_request_closed()
    ]

    pr_hooks
    |> Enum.each(fn hook ->
      assert GitlabPayload.hook_type(hook) == "merge_request"
    end)
  end

  test "branch_action() returns proper action type for all types of hooks" do
    branch_hooks = [
      GitlabHooks.push_new_branch_with_commits(),
      GitlabHooks.push_new_branch_no_commits()
    ]

    branch_hooks
    |> Enum.each(fn hook ->
      assert GitlabPayload.branch_action(hook) == "new"
    end)

    branch_hook = GitlabHooks.push_commit()

    assert GitlabPayload.branch_action(branch_hook) == "push"

    assert GitlabHooks.push_delete_branch() |> GitlabPayload.branch_action() == "deleted"
  end

  test "extract_data() returns valid data set for each type of the hook" do
    # Tags

    data = GitlabHooks.tag_push() |> GitlabPayload.extract_data("tag_push", "new")

    assert data == %{
             owner: "Jsmith",
             repo_name: "Example",
             branch_name: "refs/tags/v1.0.0",
             commit_sha: "82b3d5ae55f7080f1e6022629cdb57bfae7cccc7",
             git_ref: "refs/tags/v1.0.0",
             display_name: "v1.0.0",
             commit_message: "new_tag",
             commit_author: "GitLab dev user",
             author_email: "gitlabdev@dv6700.(none)",
             pr_name: "",
             pr_number: 0
           }

    # Branches

    data = GitlabHooks.push_new_branch_with_commits() |> GitlabPayload.extract_data("push", "new")

    assert data == %{
             owner: "Mike",
             repo_name: "Diaspora",
             branch_name: "master",
             commit_sha: "da1560886d4f094c3e6c9ef40349f7d38b5d27d7",
             git_ref: "refs/heads/master",
             display_name: "master",
             commit_message: "fixed readme",
             commit_author: "GitLab dev user",
             author_email: "gitlabdev@dv6700.(none)",
             pr_name: "",
             pr_number: 0
           }

    data = GitlabHooks.push_new_branch_no_commits() |> GitlabPayload.extract_data("push", "new")

    assert data == %{
             owner: "Mike",
             repo_name: "Diaspora",
             branch_name: "master",
             commit_sha: "",
             git_ref: "refs/heads/master",
             display_name: "master",
             commit_message: "",
             commit_author: "",
             author_email: "",
             pr_name: "",
             pr_number: 0
           }

    data = GitlabHooks.push_commit() |> GitlabPayload.extract_data("push", "push")

    assert data == %{
             owner: "Mike",
             repo_name: "Diaspora",
             branch_name: "master",
             commit_sha: "da1560886d4f094c3e6c9ef40349f7d38b5d27d7",
             git_ref: "refs/heads/master",
             display_name: "master",
             commit_message: "fixed readme",
             commit_author: "GitLab dev user",
             author_email: "gitlabdev@dv6700.(none)",
             pr_name: "",
             pr_number: 0
           }

    data = GitlabHooks.push_delete_branch() |> GitlabPayload.extract_data("push", "deleted")

    assert data == %{
             owner: "Mike",
             repo_name: "Diaspora",
             branch_name: "master",
             commit_sha: "b6568db1bc1dcd7f8b4d5a946b0b91f9dacd7327",
             git_ref: "refs/heads/master",
             display_name: "master",
             commit_message:
               "Update Catalan translation to e38cb41.\n\nSee https://gitlab.com/gitlab-org/gitlab for more information",
             commit_author: "Jordi Mallach",
             author_email: "jordi@softcatala.org",
             pr_name: "",
             pr_number: 0
           }
  end

  test "skip_ci_flag?() can detect presence of skip flags in commit message" do
    [
      %{commit_message: "[skip ci] test"},
      %{commit_message: "[ci skip] test"},
      %{commit_message: "Test [skip ci]"},
      %{commit_message: "Test [ci skip]"},
      %{commit_message: "Test [skip ci] test"},
      %{commit_message: "Test [ci skip] test"},
      %{commit_message: "Test\n Second line [skip ci] test"},
      %{commit_message: "Test\n Second line [ci skip] test"}
    ]
    |> Enum.map(fn data ->
      assert {:skip_ci, true, data} == GitlabPayload.skip_ci_flag?(data)
    end)

    assert {:skip_ci, false} == GitlabPayload.skip_ci_flag?(%{commit_message: "Test 123"})
    assert {:skip_ci, false} == GitlabPayload.skip_ci_flag?(%{commit_message: "[skip citrus[]"})
  end

  test "extract_actor_id() returns proper actor data for all types of hooks" do
    assert GitlabPayload.extract_actor_id(GitlabHooks.push_new_branch_with_commits()) == "4"
    assert GitlabPayload.extract_actor_id(GitlabHooks.push_new_branch_no_commits()) == "4"
    assert GitlabPayload.extract_actor_id(GitlabHooks.push_commit()) == "4"
    assert GitlabPayload.extract_actor_id(GitlabHooks.push_delete_branch()) == "4"
    assert GitlabPayload.extract_actor_id(GitlabHooks.tag_push()) == "1"
    assert GitlabPayload.extract_actor_id(GitlabHooks.merge_request_open()) == "1"
    assert GitlabPayload.extract_actor_id(GitlabHooks.merge_request_closed()) == "1"
  end
end
