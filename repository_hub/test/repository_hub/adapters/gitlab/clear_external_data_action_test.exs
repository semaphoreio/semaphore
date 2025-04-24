defmodule RepositoryHub.Server.GitLab.ClearExternalDataActionTest do
  alias RepositoryHub.DeployKeysModelFactory
  use RepositoryHub.ServerActionCase, async: false

  alias RepositoryHub.{
    Adapters,
    GitlabClientFactory,
    RepositoryModelFactory
  }

  alias RepositoryHub.Server.ClearExternalDataAction
  alias InternalApi.Repository.ClearExternalDataResponse
  alias RepositoryHub.InternalApiFactory

  import Mock

  setup_with_mocks(GitlabClientFactory.mocks()) do
    %{gitlab_adapter: Adapters.gitlab()}
  end

  describe "GitLab ClearExternalDataAction" do
    test "should validate request", %{gitlab_adapter: adapter} do
      request = InternalApiFactory.clear_external_data_request()

      assert {:ok, _} = ClearExternalDataAction.validate(adapter, request)
    end

    test "should fail validation with invalid repository id", %{gitlab_adapter: adapter} do
      request = InternalApiFactory.clear_external_data_request(repository_id: "invalid-id")

      assert {:error, _} = ClearExternalDataAction.validate(adapter, request)
    end

    test "should delete a repository", %{gitlab_adapter: adapter} do
      repository =
        RepositoryModelFactory.gitlab_repo(
          name: "repository",
          owner: "dummy",
          hook_id: "123"
        )

      request = InternalApiFactory.clear_external_data_request(repository_id: repository.id)

      assert {:ok, %ClearExternalDataResponse{repository: deleted_repository}} = ClearExternalDataAction.execute(adapter, request)

      assert deleted_repository.name == repository.name
      assert deleted_repository.owner == repository.owner
    end

    test "should clear a repository with deploy key", %{gitlab_adapter: adapter} do
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

      request = InternalApiFactory.clear_external_data_request(repository_id: repository.id)

      assert {:ok, %ClearExternalDataResponse{repository: deleted_repository}} = ClearExternalDataAction.execute(adapter, request)

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

      request = InternalApiFactory.clear_external_data_request(repository_id: repository.id)

      assert {:ok, %ClearExternalDataResponse{repository: deleted_repository}} = ClearExternalDataAction.execute(adapter, request)

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

      request = InternalApiFactory.clear_external_data_request(repository_id: repository.id)

      assert {:ok, %ClearExternalDataResponse{repository: deleted_repository}} = ClearExternalDataAction.execute(adapter, request)

      assert deleted_repository.name == repository.name
      assert deleted_repository.owner == repository.owner
    end
  end
end
