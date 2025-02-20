defmodule RepositoryHub.Server.Github.CreateBuildStatusActionTest do
  @moduledoc false
  use RepositoryHub.ServerActionCase, async: false

  alias RepositoryHub.Adapters
  alias RepositoryHub.Server.CreateBuildStatusAction
  alias RepositoryHub.{InternalApiFactory, GithubClientFactory, RepositoryModelFactory}

  import Mock

  setup do
    [github_repo, githubapp_repo, bitbucket_repo | _] = RepositoryModelFactory.seed_repositories()

    %{github_repo: github_repo, githubapp_repo: githubapp_repo, bitbucket_repo: bitbucket_repo}
  end

  describe "Github oauth CreateBuildStatusAction" do
    setup_with_mocks(GithubClientFactory.mocks(), context) do
      %{
        repository: context[:github_repo],
        adapter: Adapters.github_oauth()
      }
    end

    test "should create a build status", %{adapter: adapter, repository: repository} do
      request = InternalApiFactory.create_build_status_request(repository_id: repository.id)
      result = CreateBuildStatusAction.execute(adapter, request)

      assert {:ok, _response} = result
    end
  end

  describe "Github app CreateBuildStatusAction" do
    setup_with_mocks(GithubClientFactory.mocks(), context) do
      %{
        repository: context[:githubapp_repo],
        adapter: Adapters.github_app()
      }
    end

    test "should create a build status", %{adapter: adapter, repository: repository} do
      request = InternalApiFactory.create_build_status_request(repository_id: repository.id)
      result = CreateBuildStatusAction.execute(adapter, request)

      assert {:ok, _response} = result
    end

    test "should validate a request", %{adapter: adapter, repository: repository} do
      request = InternalApiFactory.create_build_status_request(repository_id: repository.id)
      assert {:ok, _} = CreateBuildStatusAction.validate(adapter, request)

      invalid_assertions = [
        repository_id: "",
        repository_id: "not an uuid",
        commit_sha: "",
        commit_sha: "not a sha",
        status: "",
        status: "not a status",
        status: 1,
        url: "",
        url: "not url",
        description: "",
        context: ""
      ]

      for {key, invalid_value} <- invalid_assertions do
        request = Map.put(request, key, invalid_value)
        assert {:error, _} = CreateBuildStatusAction.validate(adapter, request)
      end
    end
  end

  describe "Universal CreateBuildStatusAction" do
    test "should fail" do
      assert_raise Protocol.UndefinedError, fn ->
        request = InternalApiFactory.create_build_status_request()
        CreateBuildStatusAction.execute(Adapters.universal(), request)
      end
    end
  end
end
