defmodule Front.Decorators.BranchTest do
  use Front.TestCase

  alias Front.Decorators.Branch
  alias Front.Models

  describe ".decorate_many" do
    test "it decorates the branches correctly" do
      Support.FakeServices.stub_responses()

      latest_workflow = %Models.Workflow{
        id: "2cb61a21-c759-4d50-a45a-1e1eaba8c1bf",
        author_avatar_url: "https://avatars3.githubusercontent.com/u/0?v=4",
        hook: %Front.Models.RepoProxy{
          commit_message: "Fix indentation",
          commit_author: "",
          head_commit_sha: "garbble",
          id: "2cb61a21-c759-4d50-a45a-1e1eaba8c1bf",
          name: "v1.2.3",
          pr_branch_name: "master",
          pr_mergeable: false,
          repo_host_avatar_url: "https://avatars3.githubusercontent.com/u/0?v=4",
          repo_host_url: "url",
          repo_host_username: "jane",
          type: "tag",
          pr_sha: "",
          user_id: "",
          branch_name: "master",
          pr_number: "5",
          tag_name: "v1.2.3",
          forked_pr: false
        },
        author_name: "jane",
        short_commit_id: "abcdefg",
        github_commit_url: "url/commit/garbble",
        commit_message: "Fix indentation",
        branch_id: "123",
        branch_name: "v1.2.3",
        git_ref_type: "tag",
        project_id: "2cb61a21-c759-4d50-a45a-1e1eaba8c1bf",
        root_pipeline_id: "2cb61a21-c759-4d50-a45a-1e1eaba8c1bf",
        hook_id: "2cb61a21-c759-4d50-a45a-1e1eaba8c1bf",
        created_at: DateTime.from_unix!(1)
      }

      [decorated_branch] = Branch.decorate_many([latest_workflow])

      assert decorated_branch.name == "v1.2.3"
      assert decorated_branch.html_url == "/branches/123"
      assert decorated_branch.workflow == latest_workflow
      assert decorated_branch.pipelines != nil
    end
  end
end
