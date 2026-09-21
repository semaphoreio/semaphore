defmodule RepositoryHub.Server.GitLab.CreateActionTest do
  use RepositoryHub.ServerActionCase, async: false

  alias RepositoryHub.{
    Adapters,
    GitlabClientFactory
  }

  alias RepositoryHub.Server.CreateAction
  alias InternalApi.Repository.CreateResponse
  alias RepositoryHub.InternalApiFactory

  import Mock

  setup_with_mocks(GitlabClientFactory.mocks()) do
    %{gitlab_adapter: Adapters.gitlab()}
  end

  describe "GitLab CreateAction" do
    test "should create a repository", %{gitlab_adapter: adapter} do
      request =
        InternalApiFactory.create_request(
          integration_type: :GITLAB,
          repository_url: "https://gitlab.com/dummy/repository"
        )

      assert {:ok, %CreateResponse{repository: repository}} = CreateAction.execute(adapter, request)
      assert repository.url == "git@gitlab.com:dummy/repository.git"
      assert repository.provider == "gitlab"
      assert repository.integration_type == :GITLAB
    end

    test "should create a repository for subgroup namespace", %{gitlab_adapter: adapter} do
      request =
        InternalApiFactory.create_request(
          integration_type: :GITLAB,
          repository_url: "git@gitlab.com:testorg/testgroup/testrepo.git"
        )

      assert {:ok, %CreateResponse{repository: repository}} = CreateAction.execute(adapter, request)
      assert repository.owner == "testorg/testgroup"
      assert repository.name == "testrepo"
      assert repository.url == "git@gitlab.com:testorg/testgroup/testrepo.git"
      assert repository.provider == "gitlab"
      assert repository.integration_type == :GITLAB
    end

    test "should validate a request", %{gitlab_adapter: adapter} do
      assertions = [
        {false, []},
        {false, integration_type: :GIT},
        {false, integration_type: :BITBUCKET},
        {false, integration_type: :GITHUB_OAUTH_TOKEN},
        {false, integration_type: :GITHUB_APP},
        {false, integration_type: -1},
        {true, integration_type: :GITLAB, repository_url: "git@gitlab.com:dummy/repository.git"},
        {false, repository_url: ""},
        {true, integration_type: :GITLAB, repository_url: "https://gitlab.com/foo/bar"},
        {true, integration_type: :GITLAB, repository_url: "https://gitlab.com/foo/bar/baz"}
      ]

      for {true, params} <- assertions do
        request =
          InternalApiFactory.create_request()
          |> struct(params)

        assert {:ok, _} = CreateAction.validate(adapter, request)
      end

      for {false, params} <- assertions do
        request = InternalApiFactory.create_request() |> struct(params)

        assert(
          match?({:error, _}, CreateAction.validate(adapter, request)),
          "should fail validation when given #{inspect(params)}"
        )
      end
    end
  end
end
