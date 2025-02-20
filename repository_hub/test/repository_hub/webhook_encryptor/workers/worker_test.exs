defmodule RepositoryHub.WebhookEncryptor.WorkerTest do
  use RepositoryHub.Case, async: false

  alias RepositoryHub.WebhookEncryptor.Worker
  alias RepositoryHub.Model.RepositoryQuery, as: Queries

  @internal_wait_time 10

  describe "perform/1" do
    test "validates the event and aborts if invalid" do
      assert {:abort, "owner is required"} = Worker.perform(test_event("github_oauth_token", "", "repo"))
      assert {:abort, "name is required"} = Worker.perform(test_event("github_oauth_token", "owner", ""))
      assert {:abort, "integration_type is invalid"} = Worker.perform(test_event("", "owner", "repo"))
      assert {:abort, "integration_type is invalid"} = Worker.perform(test_event("foo", "owner", "repo"))

      event = test_event("github_oauth_token", "owner", "repo")
      assert {:abort, "repository_id is not valid"} = Worker.perform(Map.put(event, :repository_id, "foo"))
      assert {:abort, "project_id is not valid"} = Worker.perform(Map.put(event, :project_id, "foo"))
      assert {:abort, "token is required"} = Worker.perform(Map.put(event, :token, ""))
    end

    test "when repository is missing then abort" do
      event = test_event("github_oauth_token", "owner", "repo")
      assert {:abort, :not_found} = Worker.perform(event)
    end

    test "when repository is encrypted then abort" do
      params =
        repo_params(:github_oauth_token)
        |> Map.put(:hook_secret_enc, :crypto.strong_rand_bytes(32) |> Base.encode64())

      assert {:ok, repository} = Queries.insert(params)
      assert {:abort, :not_found} = Worker.perform(test_event(repository))
    end

    test "when webhook is created then return updated repo" do
      Tesla.Mock.mock_global(fn
        %Tesla.Env{method: :post} = env ->
          url = env.body |> Jason.decode!() |> get_in(["config", "url"])
          body = Jason.encode!(%{"id" => "hook_id", "config" => %{"url" => url}})
          %Tesla.Env{env | status: 201, body: body}

        %Tesla.Env{method: :delete} = env ->
          %Tesla.Env{env | status: 204}
      end)

      params = repo_params(:github_oauth_token)
      assert {:ok, repository} = Queries.insert(params)

      event = test_event(repository)
      assert {:ok, ^event} = Worker.perform(event)

      assert {:ok, repo} = Queries.get_by_id(repository.id)
      assert repo.hook_secret_enc
    end

    test "when webhook fails from not_found reason then rollbacks transaction" do
      Tesla.Mock.mock_global(fn
        %Tesla.Env{method: :post} = env ->
          %Tesla.Env{env | status: 404, body: %{error: "not_found"}}
      end)

      params = repo_params(:github_oauth_token)
      assert {:ok, repository} = Queries.insert(params)

      event = test_event(repository)
      assert {:abort, :not_found} = Worker.perform(event)

      assert {:ok, repo} = Queries.get_by_id(repository.id)
      refute repo.hook_secret_enc
    end

    test "when webhook fails from unprocessable reason then rollbacks transaction" do
      Tesla.Mock.mock_global(fn
        %Tesla.Env{method: :post} = env ->
          %Tesla.Env{env | status: 422, body: %{error: "unprocessable"}}
      end)

      params = repo_params(:github_oauth_token)
      assert {:ok, repository} = Queries.insert(params)

      event = test_event(repository)
      assert {:abort, :unprocessable} = Worker.perform(event)

      assert {:ok, repo} = Queries.get_by_id(repository.id)
      refute repo.hook_secret_enc
    end

    test "when webhook fails from forbidden reason then rollbacks transaction" do
      Tesla.Mock.mock_global(fn
        %Tesla.Env{method: :post} = env ->
          %Tesla.Env{env | status: 403, body: %{error: "forbidden"}}
      end)

      params = repo_params(:github_oauth_token)
      assert {:ok, repository} = Queries.insert(params)

      event = test_event(repository)
      assert {:abort, :forbidden} = Worker.perform(event)

      assert {:ok, repo} = Queries.get_by_id(repository.id)
      refute repo.hook_secret_enc
    end

    test "when webhook fails from rate limit then rollbacks transaction" do
      Tesla.Mock.mock_global(fn
        %Tesla.Env{method: :post} = env ->
          %Tesla.Env{env | status: 429, headers: [{"retry-after", "45"}]}
      end)

      params = repo_params(:github_oauth_token)
      assert {:ok, repository} = Queries.insert(params)

      event = test_event(repository)
      assert {:retry, 45} = Worker.perform(event)

      assert {:ok, repo} = Queries.get_by_id(repository.id)
      refute repo.hook_secret_enc
    end

    test "when webhook fails from other reason then rollbacks transaction" do
      Tesla.Mock.mock_global(fn
        %Tesla.Env{method: :post} = env ->
          %Tesla.Env{env | status: 500}
      end)

      params = repo_params(:github_oauth_token)
      assert {:ok, repository} = Queries.insert(params)

      event = test_event(repository)
      assert {:retry, @internal_wait_time} = Worker.perform(event)

      assert {:ok, repo} = Queries.get_by_id(repository.id)
      refute repo.hook_secret_enc
    end

    test "when webhook is created but hook was previously missing then commits transaction" do
      Tesla.Mock.mock_global(fn
        %Tesla.Env{method: :post} = env ->
          url = env.body |> Jason.decode!() |> get_in(["config", "url"])
          body = Jason.encode!(%{"id" => "hook_id", "config" => %{"url" => url}})
          %Tesla.Env{env | status: 201, body: body}

        %Tesla.Env{method: :delete} = env ->
          %Tesla.Env{env | status: 404}
      end)

      params = repo_params(:github_oauth_token)
      assert {:ok, repository} = Queries.insert(params)

      event = test_event(repository)
      assert {:ok, ^event} = Worker.perform(event)

      assert {:ok, repo} = Queries.get_by_id(repository.id)
      assert repo.hook_secret_enc
    end

    test "when webhook is created but failed to delete then commits transaction" do
      Tesla.Mock.mock_global(fn
        %Tesla.Env{method: :post} = env ->
          url = env.body |> Jason.decode!() |> get_in(["config", "url"])
          body = Jason.encode!(%{"id" => "hook_id", "config" => %{"url" => url}})
          %Tesla.Env{env | status: 201, body: body}

        %Tesla.Env{method: :delete} = env ->
          %Tesla.Env{env | status: 500}
      end)

      params = repo_params(:github_oauth_token)
      assert {:ok, repository} = Queries.insert(params)

      event = test_event(repository)
      assert {:ok, ^event} = Worker.perform(event)

      assert {:ok, repo} = Queries.get_by_id(repository.id)
      assert repo.hook_secret_enc
    end
  end

  defp repo_params(integration_type) do
    %{
      project_id: UUID.uuid4(),
      url: "http://example.com",
      owner: "owner",
      name: "repo",
      hook_id: "hook_id",
      integration_type: to_string(integration_type)
    }
  end

  defp test_event(repo) do
    %{
      git_repository: %{
        owner: repo.owner,
        name: repo.name
      },
      integration_type: to_string(repo.integration_type),
      repository_id: repo.id,
      project_id: repo.project_id,
      token: :crypto.strong_rand_bytes(32) |> Base.encode64()
    }
  end

  defp test_event(integration_type, owner, repo) do
    %{
      git_repository: %{
        owner: owner,
        name: repo
      },
      integration_type: to_string(integration_type),
      repository_id: UUID.uuid4(),
      project_id: UUID.uuid4(),
      token: :crypto.strong_rand_bytes(32) |> Base.encode64()
    }
  end
end
