defmodule RepositoryHub.Github.SyncRepositoryActionTest do
  @moduledoc false
  use RepositoryHub.ServerActionCase, async: false

  alias RepositoryHub.{
    Adapters,
    SyncRepositoryAction,
    GithubClientFactory,
    GithubClient,
    RepositoryModelFactory,
    GithubAdapter,
    Model
  }

  import Mock

  setup do
    [github_repo, githubapp_repo | _] = RepositoryModelFactory.seed_repositories()

    %{github_repo: github_repo, githubapp_repo: githubapp_repo}
  end

  defp with_find_repository(result_fun, repository) do
    [
      {GithubClient, [:passthrough], [find_repository: result_fun]},
      {GithubAdapter, [:passthrough],
       [context: fn _adapter, _id -> {:ok, %{repository: repository, github_token: "test-token"}} end]}
    ]
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
  end

  # Disconnect only on 401/404; 403/5xx/rate-limit/transport stay connected. Keyed on :http_status,
  # not the gRPC :status (401/403/5xx all share :failed_precondition) or the message.
  describe "SyncRepositoryAction disconnect policy on find_repository errors" do
    setup context do
      %{repository: context[:githubapp_repo], adapter: Adapters.github_app()}
    end

    test "rate-limit ({:error, :rate_limit}) leaves the repository connected", %{
      adapter: adapter,
      repository: repository
    } do
      with_mocks(with_find_repository(fn _params, _opts -> {:error, :rate_limit} end, repository)) do
        assert repository.connected

        assert {:error, :rate_limit} = SyncRepositoryAction.execute(adapter, repository.id)

        assert {:ok, updated} = Model.RepositoryQuery.get_by_id(repository.id)
        assert updated.connected, "a primary rate limit is transient and must not disconnect the repository"
      end
    end

    test "HTTP 401 disconnects the repository", %{adapter: adapter, repository: repository} do
      error =
        {:error,
         %{
           status: GRPC.Status.failed_precondition(),
           message: "It looks like you haven't authorized Semaphore with GitHub",
           http_status: 401
         }}

      with_mocks(with_find_repository(fn _params, _opts -> error end, repository)) do
        assert repository.connected

        assert {:error, %{http_status: 401}} = SyncRepositoryAction.execute(adapter, repository.id)

        assert {:ok, updated} = Model.RepositoryQuery.get_by_id(repository.id)
        refute updated.connected, "a 401 (auth broken) disconnects"
      end
    end

    test "HTTP 404 disconnects the repository", %{adapter: adapter, repository: repository} do
      error =
        {:error, %{status: GRPC.Status.not_found(), message: "Repository not found.", http_status: 404}}

      with_mocks(with_find_repository(fn _params, _opts -> error end, repository)) do
        assert repository.connected

        assert {:error, %{http_status: 404}} = SyncRepositoryAction.execute(adapter, repository.id)

        assert {:ok, updated} = Model.RepositoryQuery.get_by_id(repository.id)
        refute updated.connected, "a 404 (repo gone / no access) disconnects"
      end
    end

    test "HTTP 403 leaves the repository connected (secondary rate limit / ambiguous access)", %{
      adapter: adapter,
      repository: repository
    } do
      # Same gRPC status as the 401 case — only :http_status differs, proving we key on the HTTP status.
      error =
        {:error,
         %{
           status: GRPC.Status.failed_precondition(),
           message: "Error while looking up repository dummy/repository.",
           http_status: 403
         }}

      with_mocks(with_find_repository(fn _params, _opts -> error end, repository)) do
        assert repository.connected

        assert {:error, %{http_status: 403}} = SyncRepositoryAction.execute(adapter, repository.id)

        assert {:ok, updated} = Model.RepositoryQuery.get_by_id(repository.id)
        assert updated.connected, "a 403 (secondary rate limit / ambiguous access) must not disconnect"
      end
    end

    test "HTTP 5xx leaves the repository connected (GitHub outage)", %{adapter: adapter, repository: repository} do
      error =
        {:error,
         %{
           status: GRPC.Status.failed_precondition(),
           message: "Error while looking up repository dummy/repository.",
           http_status: 503
         }}

      with_mocks(with_find_repository(fn _params, _opts -> error end, repository)) do
        assert repository.connected

        assert {:error, %{http_status: 503}} = SyncRepositoryAction.execute(adapter, repository.id)

        assert {:ok, updated} = Model.RepositoryQuery.get_by_id(repository.id)
        assert updated.connected, "a GitHub 5xx outage is transient and must not disconnect"
      end
    end

    test "a transport error (raised) leaves the repository connected", %{adapter: adapter, repository: repository} do
      with_mocks(with_find_repository(fn _params, _opts -> raise "connection refused" end, repository)) do
        assert repository.connected

        assert {:error, %{status: _}} = SyncRepositoryAction.execute(adapter, repository.id)

        assert {:ok, updated} = Model.RepositoryQuery.get_by_id(repository.id)
        assert updated.connected, "a transport-level failure is transient and must not disconnect"
      end
    end
  end
end
