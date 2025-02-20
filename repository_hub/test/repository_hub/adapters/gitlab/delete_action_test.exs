defmodule RepositoryHub.Server.GitLab.DeleteActionTest do
  alias RepositoryHub.DeployKeysModelFactory
  use RepositoryHub.ServerActionCase, async: false

  alias RepositoryHub.{
    Adapters,
    GitlabClientFactory,
    RepositoryModelFactory
  }

  alias RepositoryHub.Server.DeleteAction
  alias InternalApi.Repository.DeleteResponse
  alias RepositoryHub.InternalApiFactory

  import Mock

  setup_with_mocks(GitlabClientFactory.mocks()) do
    %{gitlab_adapter: Adapters.gitlab()}
  end

  describe "GitLab DeleteAction" do
    test "should validate request", %{gitlab_adapter: adapter} do
      request = InternalApiFactory.delete_request()

      assert {:ok, _} = DeleteAction.validate(adapter, request)
    end

    test "should fail validation with invalid repository id", %{gitlab_adapter: adapter} do
      request = InternalApiFactory.delete_request(repository_id: "invalid-id")

      assert {:error, _} = DeleteAction.validate(adapter, request)
    end

    test "should delete a repository", %{gitlab_adapter: adapter} do
      repository =
        RepositoryModelFactory.gitlab_repo(
          name: "repository",
          owner: "dummy",
          hook_id: "123"
        )

      request = InternalApiFactory.delete_request(repository_id: repository.id)

      assert {:ok, %DeleteResponse{repository: deleted_repository}} = DeleteAction.execute(adapter, request)

      assert deleted_repository.name == repository.name
      assert deleted_repository.owner == repository.owner
    end

    test "should delete a repository with deploy key", %{gitlab_adapter: adapter} do
      repository =
        RepositoryModelFactory.gitlab_repo(
          name: "repository",
          owner: "dummy"
        )

      {:ok, _deploy_key} =
        DeployKeysModelFactory.create_deploy_key(
          repository_id: repository.id,
          remote_id: 456
        )

      request = InternalApiFactory.delete_request(repository_id: repository.id)

      assert {:ok, %DeleteResponse{repository: deleted_repository}} = DeleteAction.execute(adapter, request)

      assert deleted_repository.name == repository.name
      assert deleted_repository.owner == repository.owner

      assert {:error, _} = RepositoryHub.Model.DeployKeyQuery.get_by_repository_id(repository.id)
    end

    test "should handle missing deploy key gracefully", %{gitlab_adapter: adapter} do
      repository =
        RepositoryModelFactory.gitlab_repo(
          name: "repository",
          owner: "dummy"
        )

      request = InternalApiFactory.delete_request(repository_id: repository.id)

      assert {:ok, %DeleteResponse{repository: deleted_repository}} = DeleteAction.execute(adapter, request)

      assert deleted_repository.name == repository.name
      assert deleted_repository.owner == repository.owner
    end

    test "should handle missing webhook gracefully", %{gitlab_adapter: adapter} do
      repository =
        RepositoryModelFactory.gitlab_repo(
          name: "repository",
          owner: "dummy",
          hook_id: ""
        )

      request = InternalApiFactory.delete_request(repository_id: repository.id)

      assert {:ok, %DeleteResponse{repository: deleted_repository}} = DeleteAction.execute(adapter, request)

      assert deleted_repository.name == repository.name
      assert deleted_repository.owner == repository.owner
    end
  end
end
