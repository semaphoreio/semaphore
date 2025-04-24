defmodule RepositoryHub.Server.Bitbucket.ClearExternalDataActionTest do
  alias RepositoryHub.DeployKeysModelFactory
  use RepositoryHub.ServerActionCase, async: false

  alias RepositoryHub.{
    Adapters,
    BitbucketClientFactory,
    RepositoryModelFactory
  }

  alias RepositoryHub.Server.ClearExternalDataAction
  alias InternalApi.Repository.ClearExternalDataResponse
  alias RepositoryHub.InternalApiFactory
  alias RepositoryHub.BitbucketClient

  import Mock

  setup_with_mocks(BitbucketClientFactory.mocks()) do
    %{bitbucket_adapter: Adapters.bitbucket()}
  end

  describe "Bitbucket ClearExternalDataAction" do
    test "should validate request", %{bitbucket_adapter: adapter} do
      request = InternalApiFactory.clear_external_data_request()

      assert {:ok, _} = ClearExternalDataAction.validate(adapter, request)
    end

    test "should fail validation with invalid repository id", %{bitbucket_adapter: adapter} do
      request = InternalApiFactory.clear_external_data_request(repository_id: "invalid-id")

      assert {:error, _} = ClearExternalDataAction.validate(adapter, request)
    end

    test "should clear repository external data", %{bitbucket_adapter: adapter} do
      repository =
        RepositoryModelFactory.bitbucket_repo(
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

    test "should clear a repository with deploy key", %{bitbucket_adapter: adapter} do
      repository =
        RepositoryModelFactory.bitbucket_repo(
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

    test "should handle missing deploy key gracefully", %{bitbucket_adapter: adapter} do
      repository =
        RepositoryModelFactory.bitbucket_repo(
          name: "repository",
          owner: "dummy"
        )

      request = InternalApiFactory.clear_external_data_request(repository_id: repository.id)

      assert {:ok, %ClearExternalDataResponse{repository: current_repository}} =
               ClearExternalDataAction.execute(adapter, request)

      assert current_repository.name == repository.name
      assert current_repository.owner == repository.owner
    end

    test "should handle missing webhook gracefully", %{bitbucket_adapter: adapter} do
      repository =
        RepositoryModelFactory.bitbucket_repo(
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

    test "should propagate error when remove_deploy_key fails", %{bitbucket_adapter: adapter} do
      with_mock BitbucketClient, [:passthrough], remove_deploy_key: fn _, _ -> {:error, :not_found} end do
        repository =
          RepositoryModelFactory.bitbucket_repo(
            name: "repository",
            owner: "dummy",
            hook_id: "123"
          )

        request = InternalApiFactory.clear_external_data_request(repository_id: repository.id)

        assert {:error, _} = ClearExternalDataAction.execute(adapter, request)
      end
    end

    test "should propagate error when remove_webhook fails", %{bitbucket_adapter: adapter} do
      with_mock BitbucketClient, [:passthrough], remove_webhook: fn _, _ -> {:error, :not_found} end do
        repository =
          RepositoryModelFactory.bitbucket_repo(
            name: "repository",
            owner: "dummy"
          )

        {:ok, _deploy_key} =
          DeployKeysModelFactory.create_deploy_key(
            repository_id: repository.id,
            remote_id: 456
          )

        request = InternalApiFactory.clear_external_data_request(repository_id: repository.id)

        assert {:error, _} = ClearExternalDataAction.execute(adapter, request)
      end
    end
  end
end
