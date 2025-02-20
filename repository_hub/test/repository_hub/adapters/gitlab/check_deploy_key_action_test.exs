defmodule RepositoryHub.Server.Gitlab.CheckDeployKeyActionTest do
  # credo:disable-for-this-file Credo.Check.Design.DuplicatedCode
  @moduledoc false
  use RepositoryHub.ServerActionCase, async: false

  alias RepositoryHub.Adapters
  alias RepositoryHub.Server.CheckDeployKeyAction
  alias RepositoryHub.InternalApiFactory
  alias InternalApi

  alias RepositoryHub.{
    GitlabClientFactory,
    RepositoryModelFactory,
    DeployKeysModelFactory
  }

  alias InternalApi.Repository.CheckDeployKeyResponse
  import Mock

  setup_with_mocks(GitlabClientFactory.mocks()) do
    %{gitlab_adapter: Adapters.gitlab()}
  end

  describe "GitLab CheckDeployKeyAction" do
    test "should fail if deploy key doesn't not exist", %{gitlab_adapter: adapter} do
      {:ok, repository} =
        RepositoryModelFactory.create_repository(
          name: "semaphoreci",
          owner: "repositoryhub"
        )

      request = InternalApiFactory.check_deploy_key_request(repository_id: repository.id)

      assert {:error, _} = CheckDeployKeyAction.execute(adapter, request)
    end

    test "should check deploy key if it exists", %{gitlab_adapter: adapter} do
      {:ok, repository} =
        RepositoryModelFactory.create_repository(
          name: "semaphoreci",
          owner: "repositoryhub"
        )

      {:ok, deploy_key} =
        DeployKeysModelFactory.create_deploy_key(repository_id: repository.id, project_id: repository.project_id)

      request = InternalApiFactory.check_deploy_key_request(repository_id: repository.id)

      assert {:ok, %CheckDeployKeyResponse{} = response} = CheckDeployKeyAction.execute(adapter, request)
      assert response.deploy_key.created_at == RepositoryHub.Toolkit.to_proto_time(deploy_key.inserted_at)
    end
  end
end
