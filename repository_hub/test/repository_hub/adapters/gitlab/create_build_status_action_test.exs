defmodule RepositoryHub.Server.GitLab.CreateBuildStatusActionTest do
  @moduledoc false
  use RepositoryHub.ServerActionCase, async: false

  alias RepositoryHub.Adapters
  alias RepositoryHub.Server.CreateBuildStatusAction
  alias RepositoryHub.InternalApiFactory
  alias InternalApi

  alias RepositoryHub.{
    GitlabClientFactory,
    RepositoryModelFactory
  }

  alias InternalApi.Repository.CreateBuildStatusResponse
  import Mock

  setup_with_mocks(GitlabClientFactory.mocks()) do
    %{gitlab_adapter: Adapters.gitlab()}
  end

  describe "GitLab CreateBuildStatusAction" do
    test "should create build status", %{gitlab_adapter: adapter} do
      {:ok, repository} =
        RepositoryModelFactory.create_repository(
          name: "semaphoreci",
          owner: "repositoryhub"
        )

      request =
        InternalApiFactory.create_build_status_request(
          repository_id: repository.id,
          sha: "abc123",
          state: "success",
          context: "ci/semaphore",
          target_url: "https://semaphoreci.com",
          description: "Build succeeded"
        )

      assert {:ok, %CreateBuildStatusResponse{}} = CreateBuildStatusAction.execute(adapter, request)
    end

    test "should fail with invalid repository id", %{gitlab_adapter: adapter} do
      request =
        InternalApiFactory.create_build_status_request(
          repository_id: Ecto.UUID.generate(),
          sha: "abc123",
          state: "success",
          context: "ci/semaphore",
          target_url: "https://semaphoreci.com",
          description: "Build succeeded"
        )

      assert {:error, _} = CreateBuildStatusAction.execute(adapter, request)
    end

    test "should validate required fields", %{gitlab_adapter: adapter} do
      request = %InternalApi.Repository.CreateBuildStatusRequest{}

      assert {:error, _} = CreateBuildStatusAction.validate(adapter, request)
    end
  end
end
