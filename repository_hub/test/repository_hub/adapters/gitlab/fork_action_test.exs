defmodule RepositoryHub.Server.GitLab.ForkActionTest do
  @moduledoc false
  use RepositoryHub.ServerActionCase, async: false

  alias RepositoryHub.Adapters
  alias RepositoryHub.Server.ForkAction
  alias RepositoryHub.InternalApiFactory
  alias InternalApi

  alias RepositoryHub.{
    GitlabClientFactory,
    RepositoryModelFactory
  }

  alias InternalApi.Repository.ForkResponse
  import Mock

  setup_with_mocks(GitlabClientFactory.mocks()) do
    %{gitlab_adapter: Adapters.gitlab()}
  end

  describe "GitLab ForkAction" do
    test "should fork repository", %{gitlab_adapter: adapter} do
      {:ok, repository} =
        RepositoryModelFactory.create_repository(
          name: "semaphoreci",
          owner: "repositoryhub"
        )

      request =
        InternalApiFactory.fork_request(
          repository_id: repository.id,
          organization: "new-org",
          url: "git@gitlab.com:semaphoreci/repository_hub.git"
        )

      assert {:ok, %ForkResponse{} = response} = ForkAction.execute(adapter, request)
      assert response.remote_repository != nil
    end

    test "should fail with invalid repository id", %{gitlab_adapter: adapter} do
      request =
        InternalApiFactory.fork_request(
          repository_id: Ecto.UUID.generate(),
          organization: "new-org"
        )

      assert {:error, _} = ForkAction.execute(adapter, request)
    end

    test "should validate required fields", %{gitlab_adapter: adapter} do
      request = %InternalApi.Repository.ForkRequest{}

      assert {:error, _} = ForkAction.validate(adapter, request)
    end
  end
end
