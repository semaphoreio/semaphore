# credo:disable-for-this-file Credo.Check.Design.DuplicatedCode
defmodule RepositoryHub.Server.Github.RegenerateDeployKeyActionTest do
  @moduledoc false
  use RepositoryHub.ServerActionCase, async: false

  alias RepositoryHub.Adapters
  alias RepositoryHub.Server.RegenerateDeployKeyAction
  alias RepositoryHub.InternalApiFactory
  alias InternalApi

  alias RepositoryHub.{
    Model,
    GithubClient,
    GithubClientFactory,
    RepositoryIntegratorClient,
    RepositoryModelFactory,
    DeployKeysModelFactory
  }

  alias InternalApi.Repository.RegenerateDeployKeyResponse
  import Mock

  setup_with_mocks(GithubClientFactory.mocks()) do
    %{github_app_adapter: Adapters.github_app(), github_oauth_adapter: Adapters.github_oauth()}
  end

  describe "Github RegenerateDeployKeyAction" do
    test "creates the key on the repository the row points at when the transaction starts", %{
      github_app_adapter: adapter
    } do
      repository = RepositoryModelFactory.githubapp_repo()
      request = InternalApiFactory.regenerate_deploy_key_request(repository_id: repository.id)

      with_mock RepositoryIntegratorClient, [:passthrough],
        get_token: fn _integration_type, _slug, _remote_id ->
          {:ok, _} = Model.RepositoryQuery.update(repository, %{owner: "moved", name: "elsewhere"})
          {:ok, "tok"}
        end do
        assert {:ok, %RegenerateDeployKeyResponse{}} = RegenerateDeployKeyAction.execute(adapter, request)
      end

      assert_called(GithubClient.create_deploy_key(%{repo_owner: "moved", repo_name: "elsewhere"}, token: "tok"))
    end

    test "should create a deploy key if it doesnt exist", %{github_app_adapter: adapter} do
      {:ok, repository} =
        RepositoryModelFactory.create_repository(
          name: "semaphoreci",
          owner: "repositoryhub"
        )

      request = InternalApiFactory.regenerate_deploy_key_request(repository_id: repository.id)

      assert {:ok, %RegenerateDeployKeyResponse{deploy_key: _deploy_key}} =
               RegenerateDeployKeyAction.execute(adapter, request)

      assert {:ok, _new_deploy_key} = Model.DeployKeyQuery.get_by_repository_id(repository.id)
    end

    test "should regenerate deploy key if it doesnt exist", %{github_app_adapter: adapter} do
      {:ok, repository} =
        RepositoryModelFactory.create_repository(
          name: "semaphoreci",
          owner: "repositoryhub"
        )

      request = InternalApiFactory.regenerate_deploy_key_request(repository_id: repository.id)

      assert {:ok, %RegenerateDeployKeyResponse{} = _response} = RegenerateDeployKeyAction.execute(adapter, request)

      assert {:ok, _} = Model.DeployKeyQuery.get_by_repository_id(repository.id)
    end

    test "should regenerate deploy key if missing on github", %{github_app_adapter: adapter} do
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

    test "should validate required fields", %{github_app_adapter: adapter} do
      request = %InternalApi.Repository.RegenerateDeployKeyRequest{}

      assert {:error, _} = RegenerateDeployKeyAction.validate(adapter, request)
    end
  end
end
