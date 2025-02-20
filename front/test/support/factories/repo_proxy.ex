defmodule Support.Factories.RepoProxy do
  alias InternalApi.RepoProxy.DescribeResponse
  alias InternalApi.ResponseStatus
  alias InternalApi.ResponseStatus.Code

  def describe_response do
    repo_proxy_hook =
      InternalApi.RepoProxy.Hook.new(
        hook_id: "21212121-be8a-465a-b9cd-81970fb802c6",
        head_commit_sha: "96e46ddfe9be7656d6799a45e70dee0b1ada2aa4",
        repo_host_username: "radwo",
        commit_message: "Dummy commit message",
        commit_author: "radwo",
        repo_host_url:
          "https://github.com/renderedtext/internal_api/commit/736ce61d50d888e200c75bc50559bb484fbd4b2c"
      )

    InternalApi.RepoProxy.DescribeResponse.new(
      status: InternalApi.ResponseStatus.new(code: InternalApi.ResponseStatus.Code.value(:OK)),
      hook: repo_proxy_hook
    )
  end

  def bad_describe_response do
    %DescribeResponse{
      status: %ResponseStatus{
        code: Code.value(:BAD_PARAM),
        message: ""
      }
    }
  end

  def hook(branch_name \\ "master") do
    InternalApi.RepoProxy.Hook.new(
      hook_id: "2cb61a21-c759-4d50-a45a-1e1eaba8c1bf",
      head_commit_sha: "474488cb82e4784b8de8a91d3e58ed188fea4dbd",
      commit_message: "Pull new workflows on the branch page",
      repo_host_url: "",
      semaphore_email: "",
      repo_host_username: "jane",
      repo_host_email: "",
      user_id: "",
      repo_host_avatar_url: "https://avatars3.githubusercontent.com/u/0?v=4",
      branch_name: branch_name,
      tag_name: "v1.2.3",
      pr_name: "Update README.md",
      pr_branch_name: "master",
      pr_number: "5",
      git_ref_type: InternalApi.RepoProxy.Hook.Type.value(:BRANCH)
    )
  end
end
