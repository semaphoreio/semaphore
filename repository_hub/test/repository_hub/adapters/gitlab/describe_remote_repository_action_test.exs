defmodule RepositoryHub.Server.GitLab.DescribeRemoteRepositoryActionTest do
  @moduledoc false
  use RepositoryHub.ServerActionCase, async: false

  alias RepositoryHub.Adapters
  alias RepositoryHub.Server.DescribeRemoteRepositoryAction
  alias RepositoryHub.InternalApiFactory
  alias InternalApi

  alias RepositoryHub.GitlabClientFactory

  alias InternalApi.Repository.DescribeRemoteRepositoryResponse
  import Mock

  setup_with_mocks(GitlabClientFactory.mocks()) do
    %{gitlab_adapter: Adapters.gitlab()}
  end

  describe "GitLab DescribeRemoteRepositoryAction" do
    test "should describe repository", %{gitlab_adapter: adapter} do
      request =
        InternalApiFactory.describe_remote_repository_request(
          url: "https://gitlab.com/repositoryhub/semaphoreci",
          integration_type: :GITLAB
        )

      assert {:ok, %DescribeRemoteRepositoryResponse{} = response} =
               DescribeRemoteRepositoryAction.execute(adapter, request)

      assert response.remote_repository.name == "semaphoreci"
      assert response.remote_repository.full_name == "repositoryhub/semaphoreci"
    end

    test "should describe repository in subgroup namespace", %{gitlab_adapter: adapter} do
      request =
        InternalApiFactory.describe_remote_repository_request(
          url: "https://gitlab.com/testorg/testgroup/testrepo",
          integration_type: :GITLAB
        )

      assert {:ok, %DescribeRemoteRepositoryResponse{} = response} =
               DescribeRemoteRepositoryAction.execute(adapter, request)

      assert response.remote_repository.name == "testrepo"
      assert response.remote_repository.full_name == "testorg/testgroup/testrepo"
    end

    test "should fail with invalid repository url", %{gitlab_adapter: adapter} do
      request =
        InternalApiFactory.describe_remote_repository_request(
          url: "invalid-url",
          integration_type: :GITLAB
        )

      assert {:error, _} = DescribeRemoteRepositoryAction.execute(adapter, request)
    end
  end
end
