defmodule RepositoryHub.Server.GetSshKeyActionTest do
  @moduledoc false
  use RepositoryHub.ServerActionCase, async: false

  alias RepositoryHub.Adapters
  alias RepositoryHub.Server.GetSshKeyAction
  alias RepositoryHub.{InternalApiFactory, RepositoryModelFactory, DeployKeysModelFactory}

  setup do
    {:ok, repository} = RepositoryModelFactory.create_repository()

    {:ok, deploy_key} =
      DeployKeysModelFactory.create_deploy_key(project_id: repository.project_id, repository_id: repository.id)

    %{deploy_key: deploy_key, repository: repository}
  end

  describe "Universal GetSshKeyAction" do
    test "should fetch a ssh key", %{deploy_key: deploy_key, repository: repository} do
      request = InternalApiFactory.get_ssh_key_request(repository_id: repository.id)
      result = GetSshKeyAction.execute(Adapters.pick!(request), request)

      assert {:ok, response} = result

      assert response.private_ssh_key ==
               RepositoryHub.Encryptor.decrypt!(
                 RepositoryHub.DeployKeyEncryptor,
                 deploy_key.private_key_enc,
                 "semaphore-#{repository.project_id}"
               )
    end

    test "should validate a request", %{repository: repository} do
      request = InternalApiFactory.get_ssh_key_request(repository_id: repository.id)
      assert {:ok, _} = GetSshKeyAction.validate(Adapters.universal(), request)
      assert {:error, _} = GetSshKeyAction.validate(Adapters.universal(), %{request | repository_id: ""})
      assert {:error, _} = GetSshKeyAction.validate(Adapters.universal(), %{request | repository_id: "not uuid"})
    end
  end
end
