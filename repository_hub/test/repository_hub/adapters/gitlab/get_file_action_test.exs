defmodule RepositoryHub.Server.GitLab.GetFileActionTest do
  @moduledoc false
  use RepositoryHub.ServerActionCase, async: false

  alias RepositoryHub.Adapters
  alias RepositoryHub.Server.GetFileAction
  alias RepositoryHub.InternalApiFactory
  alias InternalApi

  alias RepositoryHub.{
    GitlabClientFactory,
    RepositoryModelFactory
  }

  alias InternalApi.Repository.GetFileResponse
  import Mock

  setup_with_mocks(GitlabClientFactory.mocks()) do
    %{gitlab_adapter: Adapters.gitlab()}
  end

  describe "GitLab GetFileAction" do
    test "should get file content", %{gitlab_adapter: adapter} do
      {:ok, repository} =
        RepositoryModelFactory.create_repository(
          name: "semaphoreci",
          owner: "repositoryhub"
        )

      request =
        InternalApiFactory.get_file_request(
          repository_id: repository.id,
          path: "README.md",
          commit_sha: "abc123"
        )

      assert {:ok, %GetFileResponse{file: file}} = GetFileAction.execute(adapter, request)
      assert file.path == request.path
      assert file.content != nil
    end

    test "should fail with invalid repository id", %{gitlab_adapter: adapter} do
      request =
        InternalApiFactory.get_file_request(
          repository_id: Ecto.UUID.generate(),
          path: "README.md",
          commit_sha: "abc123"
        )

      assert {:error, _} = GetFileAction.execute(adapter, request)
    end

    test "should fail with non-existent file", %{gitlab_adapter: adapter} do
      {:ok, repository} =
        RepositoryModelFactory.create_repository(
          name: "semaphoreci",
          owner: "repositoryhub"
        )

      request =
        InternalApiFactory.get_file_request(
          repository_id: repository.id,
          path: "non-existent-file.txt",
          commit_sha: "abc123"
        )

      assert {:error, _} = GetFileAction.execute(adapter, request)
    end
  end
end
