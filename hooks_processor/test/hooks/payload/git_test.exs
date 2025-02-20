defmodule HooksProcessor.Hooks.Payload.GitTest do
  use ExUnit.Case

  alias HooksProcessor.Hooks.Payload.Git, as: GitPayload
  alias Support.GitHooks

  test "hook_type() returns proper hook type for all types of hooks" do
    assert GitHooks.tag() |> GitPayload.hook_type() == "tag"

    assert GitHooks.branch() |> GitPayload.hook_type() == "branch"
  end

  test "skip_ci_flag?() can detect presence of skip flags in commit message" do
    assert {:skip_ci, false} = GitHooks.tag() |> GitPayload.extract_data("tag") |> GitPayload.skip_ci_flag?()
    assert {:skip_ci, false} = GitHooks.branch() |> GitPayload.extract_data("branch") |> GitPayload.skip_ci_flag?()

    assert {:skip_ci, true, _} =
             GitHooks.skip_branch() |> GitPayload.extract_data("branch") |> GitPayload.skip_ci_flag?()
  end

  test "extract_data() returns valid data set for each type of the hook" do
    data = GitHooks.tag() |> GitPayload.extract_data("tag")
    assert data.branch_name == "refs/tags/v1.0.1"
    assert data.git_ref == "refs/tags/v1.0.1"
    assert data.display_name == "v1.0.1"
    assert data.commit_sha == "023becf74ae8a5d93911db4bad7967f94343b44b"
    assert data.commit_message == "Initial commit"
    assert data.commit_author == "Radek"
    assert data.author_email == "radek@example.com"

    data = GitHooks.branch() |> GitPayload.extract_data("branch")
    assert data.branch_name == "master"
    assert data.git_ref == "refs/heads/master"
    assert data.display_name == "master"
    assert data.commit_sha == "023becf74ae8a5d93911db4bad7967f94343b44b"
    assert data.commit_message == "Initial commit"
    assert data.commit_author == "Radek"
    assert data.author_email == "radek@example.com"
  end
end
