defmodule RepositoryHub.Github.SyncRepositoryActionTest do
  @moduledoc false
  use RepositoryHub.ServerActionCase, async: false

  alias RepositoryHub.Adapters
  alias RepositoryHub.SyncRepositoryAction
  alias RepositoryHub.GithubClientFactory
  alias RepositoryHub.RepositoryModelFactory

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
