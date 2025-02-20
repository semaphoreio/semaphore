defmodule RepositoryHub.Server.Git.CreateActionTest do
  use RepositoryHub.ServerActionCase, async: true

  alias RepositoryHub.Adapters
  alias RepositoryHub.Server.CreateAction
  alias InternalApi.Repository.CreateResponse
  alias RepositoryHub.InternalApiFactory
  alias InternalApi

  setup do
    adapter = Adapters.git()

    {:ok, %{adapter: adapter}}
  end

  describe "Git CreateAction" do
    test "should create a repository", %{adapter: adapter} do
      request = InternalApiFactory.create_request(integration_type: :GIT)

      assert {:ok, %CreateResponse{repository: _repository}} = CreateAction.execute(adapter, request)
    end

    test "should validate a request", %{adapter: adapter} do
      assertions = [
        {false, []},
        {true, integration_type: :GIT},
        {false, integration_type: :BITBUCKET},
        {false, integration_type: :GITHUB_OAUTH_TOKEN},
        {false, integration_type: :GITHUB_APP},
        {false, integration_type: -1},
        {false, integration_type: :GITLAB},
        {false, repository_url: ""},
        {true, integration_type: :GIT, repository_url: "https://gitlab.com/foo/bar"}
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
