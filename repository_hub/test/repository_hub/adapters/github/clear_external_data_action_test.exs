defmodule RepositoryHub.Server.Github.ClearExternalDataActionTest do
  alias RepositoryHub.DeployKeysModelFactory
  use RepositoryHub.ServerActionCase, async: false

  alias RepositoryHub.{
    Adapters,
    GithubClientFactory,
    RepositoryModelFactory
  }

  alias RepositoryHub.Server.ClearExternalDataAction
  alias InternalApi.Repository.ClearExternalDataResponse
  alias RepositoryHub.InternalApiFactory

  import Mock

  setup_with_mocks(GithubClientFactory.mocks()) do
    %{github_adapter: Adapters.github_app()}
  end

  describe "Github ClearExternalDataAction" do
    test "should validate request", %{github_adapter: adapter} do
      request = InternalApiFactory.clear_external_data_request()

      assert {:ok, _} = ClearExternalDataAction.validate(adapter, request)
    end

    test "should fail validation with invalid repository id", %{github_adapter: adapter} do
      request = InternalApiFactory.clear_external_data_request(repository_id: "invalid-id")

      assert {:error, _} = ClearExternalDataAction.validate(adapter, request)
    end

    test "should clear repository external data", %{github_adapter: adapter} do
      repository =
        RepositoryModelFactory.github_repo(
          name: "repository",
          owner: "dummy",
          hook_id: "123"
        )

      request = InternalApiFactory.clear_external_data_request(repository_id: repository.id)

      assert {:ok, %ClearExternalDataResponse{repository: current_repository}} =
               ClearExternalDataAction.execute(adapter, request)

      assert current_repository.name == repository.name
      assert current_repository.owner == repository.owner
    end

    test "should clear a repository with deploy key", %{github_adapter: adapter} do
      repository =
        RepositoryModelFactory.github_repo(
          name: "repository",
          owner: "dummy"
        )

      {:ok, _deploy_key} =
        DeployKeysModelFactory.create_deploy_key(
          repository_id: repository.id,
          remote_id: 456
        )

      request = InternalApiFactory.clear_external_data_request(repository_id: repository.id)

      assert {:ok, %ClearExternalDataResponse{repository: current_repository}} =
               ClearExternalDataAction.execute(adapter, request)

      assert current_repository.name == repository.name
      assert current_repository.owner == repository.owner

      assert {:error, _} = RepositoryHub.Model.DeployKeyQuery.get_by_repository_id(repository.id)
    end

    test "should handle missing deploy key gracefully", %{github_adapter: adapter} do
      repository =
        RepositoryModelFactory.github_repo(
          name: "repository",
          owner: "dummy"
        )

      request = InternalApiFactory.clear_external_data_request(repository_id: repository.id)

      assert {:ok, %ClearExternalDataResponse{repository: current_repository}} =
               ClearExternalDataAction.execute(adapter, request)

      assert current_repository.name == repository.name
      assert current_repository.owner == repository.owner
    end

    test "should handle missing webhook gracefully", %{github_adapter: adapter} do
      repository =
        RepositoryModelFactory.github_repo(
          name: "repository",
          owner: "dummy",
          hook_id: ""
        )

      request = InternalApiFactory.clear_external_data_request(repository_id: repository.id)

      assert {:ok, %ClearExternalDataResponse{repository: current_repository}} =
               ClearExternalDataAction.execute(adapter, request)

      assert current_repository.name == repository.name
      assert current_repository.owner == repository.owner
    end
  end
end
