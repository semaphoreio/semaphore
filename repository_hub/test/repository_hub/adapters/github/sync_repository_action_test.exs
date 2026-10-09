defmodule RepositoryHub.Github.SyncRepositoryActionTest do
  @moduledoc false
  use RepositoryHub.ServerActionCase, async: false

  alias RepositoryHub.{
    Adapters,
    SyncRepositoryAction,
    GithubClientFactory,
    RepositoryModelFactory,
    GithubAdapter,
    GithubClient,
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
        assert repository.connected

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

    test "heals a renamed repository by looking it up by remote_id", %{adapter: adapter} do
      repository =
        RepositoryModelFactory.githubapp_repo(
          owner: "old-owner",
          name: "old-name",
          url: "git@github.com:old-owner/old-name.git",
          remote_id: "401025",
          connected: false
        )

      :meck.expect(GithubClient, :find_repository, fn
        %{remote_id: "401025"}, _opts ->
          {:ok,
           %{
             id: "401025",
             with_admin_access?: true,
             permissions: %{"admin" => true},
             description: "",
             is_private?: true,
             created_at: DateTime.utc_now(),
             provider: "github",
             owner: "new-owner",
             name: "new-name",
             full_name: "new-owner/new-name",
             default_branch: "main",
             ssh_url: "git@github.com:new-owner/new-name.git"
           }}

        _params, _opts ->
          {:error, %{status: GRPC.Status.failed_precondition(), message: "Moved Permanently"}}
      end)

      assert {:ok, updated_repository} = SyncRepositoryAction.execute(adapter, repository.id)

      assert updated_repository.owner == "new-owner"
      assert updated_repository.name == "new-name"
      assert updated_repository.url == "git@github.com:new-owner/new-name.git"
      assert updated_repository.remote_id == "401025"
      assert updated_repository.connected

      assert_called(
        GithubClient.find_repository(
          %{repo_owner: "old-owner", repo_name: "old-name", remote_id: "401025"},
          :_
        )
      )
    end
  end
end
