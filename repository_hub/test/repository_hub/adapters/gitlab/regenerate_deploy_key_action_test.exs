# credo:disable-for-this-file Credo.Check.Design.DuplicatedCode
defmodule RepositoryHub.Server.GitLab.RegenerateDeployKeyActionTest do
  @moduledoc false
  use RepositoryHub.ServerActionCase, async: false

  alias RepositoryHub.Adapters
  alias RepositoryHub.Server.RegenerateDeployKeyAction
  alias RepositoryHub.InternalApiFactory
  alias InternalApi

  alias RepositoryHub.{
    Model,
    GitlabClientFactory,
    RepositoryModelFactory,
    DeployKeysModelFactory
  }

  alias InternalApi.Repository.RegenerateDeployKeyResponse
  import Mock

  setup_with_mocks(GitlabClientFactory.mocks()) do
    %{gitlab_adapter: Adapters.gitlab()}
  end

  describe "GitLab RegenerateDeployKeyAction" do
    test "should regenerate deploy key", %{gitlab_adapter: adapter} do
      {:ok, repository} =
        RepositoryModelFactory.create_repository(
          name: "semaphoreci",
          owner: "repositoryhub"
        )

      {:ok, _old_deploy_key} =
        DeployKeysModelFactory.create_deploy_key(
          repository_id: repository.id,
          project_id: repository.project_id
        )

      request = InternalApiFactory.regenerate_deploy_key_request(repository_id: repository.id)

      assert {:ok, %RegenerateDeployKeyResponse{}} = RegenerateDeployKeyAction.execute(adapter, request)
    end

    test "should regenerate deploy key if it doesnt exist", %{gitlab_adapter: adapter} do
      {:ok, repository} =
        RepositoryModelFactory.create_repository(
          name: "semaphoreci",
          owner: "repositoryhub"
        )

      request = InternalApiFactory.regenerate_deploy_key_request(repository_id: repository.id)

      assert {:ok, %RegenerateDeployKeyResponse{} = _response} = RegenerateDeployKeyAction.execute(adapter, request)

      assert {:ok, _} = Model.DeployKeyQuery.get_by_repository_id(repository.id)
    end

    test "should regenerate deploy key if missing on gitlab", %{gitlab_adapter: adapter} do
      {:ok, repository} =
        RepositoryModelFactory.create_repository(
          name: "semaphoreci",
          owner: "repositoryhub"
        )

      assert {:ok, deploy_key} = DeployKeysModelFactory.create_deploy_key(repository_id: repository.id)

      request = InternalApiFactory.regenerate_deploy_key_request(repository_id: repository.id)

      assert {:ok, %RegenerateDeployKeyResponse{} = _response} = RegenerateDeployKeyAction.execute(adapter, request)

      assert {:ok, new_deploy_key} = Model.DeployKeyQuery.get_by_repository_id(repository.id)

      assert deploy_key.id != new_deploy_key.id
      assert deploy_key.remote_id != new_deploy_key.remote_id
    end

    test "should validate required fields", %{gitlab_adapter: adapter} do
      request = %InternalApi.Repository.RegenerateDeployKeyRequest{}

      assert {:error, _} = RegenerateDeployKeyAction.validate(adapter, request)
    end
  end
end
