defmodule HooksProcessor.Hooks.Payload.BitbucketTest do
  use ExUnit.Case

  alias HooksProcessor.Hooks.Payload.Bitbucket, as: BBPayload
  alias Support.BitbucketHooks

  test "hook_type() returns proper hook type for all types of hooks" do
    # Branch

    branch_hooks = [
      BitbucketHooks.push_new_branch_with_commits(),
      BitbucketHooks.push_new_branch_no_commits(),
      BitbucketHooks.push_commit(),
      BitbucketHooks.push_commit_force(),
      BitbucketHooks.branch_deletion()
    ]

    branch_hooks
    |> Enum.each(fn hook ->
      assert BBPayload.hook_type(hook) == "branch"
    end)

    # Tag

    tag_hooks = [
      BitbucketHooks.push_annoted_tag(),
      BitbucketHooks.push_lightweight_tag(),
      BitbucketHooks.tag_deletion()
    ]

    tag_hooks
    |> Enum.each(fn hook ->
      assert BBPayload.hook_type(hook) == "tag"
    end)

    # PR

    pr_hooks = [
      BitbucketHooks.pull_request_open(),
      BitbucketHooks.pull_request_closed()
    ]

    pr_hooks
    |> Enum.each(fn hook ->
      assert BBPayload.hook_type(hook) == "pullrequest"
    end)
  end

  test "branch_action() returns proper action type for all types of hooks" do
    branch_hooks = [
      BitbucketHooks.push_new_branch_with_commits(),
      BitbucketHooks.push_new_branch_no_commits(),
      BitbucketHooks.push_annoted_tag(),
      BitbucketHooks.push_lightweight_tag()
    ]

    branch_hooks
    |> Enum.each(fn hook ->
      assert BBPayload.branch_action(hook) == "new"
    end)

    branch_hooks = [
      BitbucketHooks.push_commit(),
      BitbucketHooks.push_commit_force()
    ]

    branch_hooks
    |> Enum.each(fn hook ->
      assert BBPayload.branch_action(hook) == "push"
    end)

    branch_hooks = [
      BitbucketHooks.branch_deletion(),
      BitbucketHooks.tag_deletion()
    ]

    branch_hooks
    |> Enum.each(fn hook ->
      assert BBPayload.branch_action(hook) == "deleted"
    end)
  end

  test "extract_data() returns valid data set for each type of the hook" do
    # Tags

    data = BitbucketHooks.push_annoted_tag() |> BBPayload.extract_data("tag", "new")
    assert data.branch_name == "refs/tags/v1.6"
    assert data.git_ref == "refs/tags/v1.6"
    assert data.display_name == "v1.6"
    assert data.owner == "milana_stojadinov"
    assert data.repo_name == "elixir-project"
    assert data.commit_sha == "daf07dd85350b95d05a7fe898e07022c5dcd95b9"
    assert data.commit_message == "Push commit\n"
    assert data.commit_author == "milana_stojadinov"
    assert data.pr_name == ""
    assert data.pr_number == 0

    data = BitbucketHooks.push_lightweight_tag() |> BBPayload.extract_data("tag", "new")
    assert data.branch_name == "refs/tags/v1.6-lw"
    assert data.git_ref == "refs/tags/v1.6-lw"
    assert data.display_name == "v1.6-lw"
    assert data.owner == "milana_stojadinov"
    assert data.repo_name == "elixir-project"
    assert data.commit_sha == "daf07dd85350b95d05a7fe898e07022c5dcd95b9"
    assert data.commit_message == "Push commit\n"
    assert data.commit_author == "milana_stojadinov"
    assert data.pr_name == ""
    assert data.pr_number == 0

    data = BitbucketHooks.tag_deletion() |> BBPayload.extract_data("tag", "deleted")
    assert data.branch_name == "refs/tags/v1.0-alpha"
    assert data.git_ref == "refs/tags/v1.0-alpha"
    assert data.display_name == "v1.0-alpha"
    assert data.owner == "fake-test-user-1234"
    assert data.repo_name == "fake-test-repo-2025"
    assert data.commit_sha == "86efd1e2f788d237a9b8d6da5c04683d289ad805"
    assert data.commit_message == "README.md created online with Bitbucket"
    assert data.commit_author == "fake-test-user-1234"
    assert data.pr_name == ""
    assert data.pr_number == 0

    # Branches

    data = BitbucketHooks.push_new_branch_with_commits() |> BBPayload.extract_data("branch", "new")

    assert data.branch_name == "new-branch-push-new-commits"
    assert data.git_ref == "refs/heads/new-branch-push-new-commits"
    assert data.display_name == "new-branch-push-new-commits"
    assert data.owner == "milana_stojadinov"
    assert data.repo_name == "elixir-project"
    assert data.commit_sha == "2a585bde481f0d5b3a10b10997210b6eb4893897"
    assert data.commit_message == "Update readme\n"
    assert data.commit_author == "milana_stojadinov"
    assert data.pr_name == ""
    assert data.pr_number == 0

    data = BitbucketHooks.push_new_branch_no_commits() |> BBPayload.extract_data("branch", "new")
    assert data.branch_name == "new-branch-push"
    assert data.git_ref == "refs/heads/new-branch-push"
    assert data.display_name == "new-branch-push"
    assert data.owner == "milana_stojadinov"
    assert data.repo_name == "elixir-project"
    assert data.commit_sha == "c699bacf22afa6f423ec4bc09da26a127559bc9a"
    assert data.commit_message == "Remove build badge\n"
    assert data.commit_author == "milana_stojadinov"
    assert data.pr_name == ""
    assert data.pr_number == 0

    data = BitbucketHooks.push_commit() |> BBPayload.extract_data("branch", "push")
    assert data.branch_name == "new-branch-push-new-commits"
    assert data.git_ref == "refs/heads/new-branch-push-new-commits"
    assert data.display_name == "new-branch-push-new-commits"
    assert data.owner == "milana_stojadinov"
    assert data.repo_name == "elixir-project"
    assert data.commit_sha == "daf07dd85350b95d05a7fe898e07022c5dcd95b9"
    assert data.commit_message == "Push commit\n"
    assert data.commit_author == "milana_stojadinov"
    assert data.pr_name == ""
    assert data.pr_number == 0

    data = BitbucketHooks.push_commit_force() |> BBPayload.extract_data("branch", "push")
    assert data.branch_name == "new-branch-push-new-commits"
    assert data.git_ref == "refs/heads/new-branch-push-new-commits"
    assert data.display_name == "new-branch-push-new-commits"
    assert data.owner == "milana_stojadinov"
    assert data.repo_name == "elixir-project"
    assert data.commit_sha == "d3da4886495b865f836a0c77daa9c8e080b136d1"
    assert data.commit_message == "Push new commit - force push\n"
    assert data.commit_author == "milana_stojadinov"
    assert data.pr_name == ""
    assert data.pr_number == 0

    data = BitbucketHooks.branch_deletion() |> BBPayload.extract_data("branch", "deleted")
    assert data.branch_name == "mtmp1123333333"
    assert data.git_ref == "refs/heads/mtmp1123333333"
    assert data.display_name == "mtmp1123333333"
    assert data.owner == "milana_stojadinov"
    assert data.repo_name == "elixir-project"
    assert data.commit_sha == "d2b7d8ca15effafc1a24ac5fd099f34b5447c9ad"
    assert data.commit_message == "Update readme\n"
    assert data.commit_author == "milana_stojadinov"
    assert data.pr_name == ""
    assert data.pr_number == 0
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
      assert {:skip_ci, true, data} == BBPayload.skip_ci_flag?(data)
    end)

    assert {:skip_ci, false} == BBPayload.skip_ci_flag?(%{commit_message: "Test 123"})
    assert {:skip_ci, false} == BBPayload.skip_ci_flag?(%{commit_message: "[skip citrus[]"})
  end

  test "extract_actor_id() returns proper actor data for all types of hooks" do
    assert BBPayload.extract_actor_id(BitbucketHooks.push_new_branch_with_commits()) ==
             "{53c5afd4-936e-4ded-9b8a-398f527a33c9}"

    assert BBPayload.extract_actor_id(BitbucketHooks.push_new_branch_no_commits()) ==
             "{53c5afd4-936e-4ded-9b8a-398f527a33c9}"

    assert BBPayload.extract_actor_id(BitbucketHooks.push_commit()) == "{53c5afd4-936e-4ded-9b8a-398f527a33c9}"
    assert BBPayload.extract_actor_id(BitbucketHooks.push_commit_force()) == "{53c5afd4-936e-4ded-9b8a-398f527a33c9}"
    assert BBPayload.extract_actor_id(BitbucketHooks.branch_deletion()) == "{53c5afd4-936e-4ded-9b8a-398f527a33c9}"
    assert BBPayload.extract_actor_id(BitbucketHooks.push_annoted_tag()) == "{53c5afd4-936e-4ded-9b8a-398f527a33c9}"

    assert BBPayload.extract_actor_id(BitbucketHooks.push_lightweight_tag()) ==
             "{53c5afd4-936e-4ded-9b8a-398f527a33c9}"

    assert BBPayload.extract_actor_id(BitbucketHooks.tag_deletion()) == "{00000000-6000-4000-9000-000000000012}"

    assert BBPayload.extract_actor_id(BitbucketHooks.pull_request_open()) == "{53c5afd4-936e-4ded-9b8a-398f527a33c9}"
    assert BBPayload.extract_actor_id(BitbucketHooks.pull_request_closed()) == "{53c5afd4-936e-4ded-9b8a-398f527a33c9}"
  end
end
