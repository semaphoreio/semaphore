defmodule RepositoryHub.Server.Bitbucket.UpdateActionTest do
  @moduledoc false
  use RepositoryHub.ServerActionCase, async: false

  alias RepositoryHub.Adapters
  alias RepositoryHub.Server.UpdateAction
  alias RepositoryHub.InternalApiFactory

  alias RepositoryHub.{
    BitbucketClient,
    BitbucketClientFactory,
    DeployKeysModelFactory,
    RepositoryModelFactory
  }

  alias InternalApi.Repository.UpdateResponse
  import Mock

  setup_with_mocks(BitbucketClientFactory.mocks()) do
    %{bitbucket_adapter: Adapters.bitbucket()}
  end

  describe "Bitbucket UpdateAction" do
    test "stores the id of a newly created webhook when the url changes", %{bitbucket_adapter: adapter} do
      repository = RepositoryModelFactory.bitbucket_repo(url: "git@bitbucket.org:dummy/repository.git")
      DeployKeysModelFactory.create_deploy_key(project_id: repository.project_id, repository_id: repository.id)

      :meck.expect(BitbucketClient, :find_webhook, fn _params, _opts ->
        {:error, %{status: GRPC.Status.not_found(), message: "Webhook not found"}}
      end)

      :meck.expect(BitbucketClient, :create_webhook, fn _params, _opts ->
        {:ok, %{id: "{new-webhook-uuid}", url: "example.com/hooks/bitbucket"}}
      end)

      request =
        InternalApiFactory.update_request(
          repository_id: repository.id,
          url: "git@bitbucket.org:dummy/repository-2.git"
        )

      assert %UpdateResponse{} = UpdateAction.execute(adapter, request)

      {:ok, updated_repository} = RepositoryHub.Model.RepositoryQuery.get_by_id(repository.id)
      assert updated_repository.name == "repository-2"
      assert updated_repository.hook_id == "{new-webhook-uuid}"
    end
  end
end
