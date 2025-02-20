defmodule Support.Stubs.Hook do
  alias Support.Stubs.{DB, UUID}

  def init do
    DB.add_table(:hooks, [:id, :project_id, :branch_id, :api_model])

    __MODULE__.Grpc.init()
  end

  def create(branch) do
    hook = build(branch)

    DB.insert(:hooks, %{
      id: hook.hook_id,
      project_id: branch.project_id,
      branch_id: branch.id,
      api_model: hook
    })
  end

  def build(branch) do
    InternalApi.RepoProxy.Hook.new(
      hook_id: UUID.gen(),
      head_commit_sha: "474488cb82e4784b8de8a91d3e58ed188fea4dbd",
      commit_message: "Pull new workflows on the branch page",
      repo_host_url: "",
      semaphore_email: "",
      repo_host_username: "jane",
      repo_host_email: "",
      user_id: "",
      repo_host_avatar_url: "https://avatars3.githubusercontent.com/u/0?v=4",
      branch_name: branch.name,
      tag_name: "v1.2.3",
      pr_name: "Update README.md",
      pr_branch_name: branch.name,
      pr_number: "5",
      git_ref_type: InternalApi.RepoProxy.Hook.Type.value(:BRANCH)
    )
  end

  defmodule Grpc do
    alias InternalApi.RepoProxy.DescribeManyResponse
    alias InternalApi.RepoProxy.DescribeResponse
    alias Support.Stubs.DB

    def init do
      alias Support.FakeServices.RepoProxyService

      FunRegistry.set!(RepoProxyService, :describe, &__MODULE__.describe/2)
      FunRegistry.set!(RepoProxyService, :describe_many, &__MODULE__.describe_many/2)
    end

    def describe(req, _) do
      hook = DB.find_by(:hooks, :id, req.hook_id)

      DescribeResponse.new(status: ok(), hook: hook.api_model)
    end

    def describe_many(req, _) do
      hooks =
        DB.all(:hooks)
        |> Enum.filter(fn h -> Enum.member?(req.hook_ids, h.id) end)
        |> DB.extract(:api_model)

      DescribeManyResponse.new(status: ok(), hooks: hooks)
    end

    defp ok do
      InternalApi.ResponseStatus.new(code: InternalApi.ResponseStatus.Code.value(:OK))
    end
  end
end
