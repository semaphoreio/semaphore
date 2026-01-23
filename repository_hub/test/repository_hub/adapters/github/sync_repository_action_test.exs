defmodule RepositoryHub.Github.SyncRepositoryActionTest do
  @moduledoc false
  use RepositoryHub.ServerActionCase, async: false

  alias RepositoryHub.{
    Adapters,
    SyncRepositoryAction,
    GithubClientFactory,
    RepositoryModelFactory,
    GithubAdapter,
    Model
  }

  import Mock

  setup do
    [github_repo, githubapp_repo | _] = RepositoryModelFactory.seed_repositories()

    %{github_repo: github_repo, githubapp_repo: githubapp_repo}
  end

  describe "Github oauth SyncRepositoryAction" do
    setup_with_mocks(GithubClientFactory.mocks(), context) do
      %{
        repository: context[:github_repo],
        adapter: Adapters.github_oauth()
      }
    end

    test "should sync repository data", %{adapter: adapter, repository: repository} do
      assert repository.url == "http://github.com/dummy/repository.git"

      assert {:ok, updated_repository} = SyncRepositoryAction.execute(adapter, repository.id)

      assert updated_repository.id == repository.id
      assert updated_repository.url == "git@github.com:dummy/repository.git"
    end

    test "marks repository as not connected on disconnect error", %{adapter: adapter, repository: repository} do
      mocks =
        GithubClientFactory.mocks() ++
          [
            {GithubAdapter, [:passthrough],
             [context: fn _adapter, _repository_id -> {:error, "Token for not found."} end]}
          ]

      with_mocks(mocks) do
        assert {:error, "Token for not found."} = SyncRepositoryAction.execute(adapter, repository.id)

        assert {:ok, updated_repository} = Model.RepositoryQuery.get_by_id(repository.id)
        refute updated_repository.connected
      end
    end
  end

  describe "Github app SyncRepositoryAction" do
    setup_with_mocks(GithubClientFactory.mocks(), context) do
      %{
        repository: context[:githubapp_repo],
        adapter: Adapters.github_app()
      }
    end

    test "should sync repository data", %{adapter: adapter, repository: repository} do
      assert repository.url == "http://github.com/dummy/repository.git"

      assert {:ok, updated_repository} = SyncRepositoryAction.execute(adapter, repository.id)

      assert updated_repository.id == repository.id
      assert updated_repository.url == "git@github.com:dummy/repository.git"
    end
  end
end
