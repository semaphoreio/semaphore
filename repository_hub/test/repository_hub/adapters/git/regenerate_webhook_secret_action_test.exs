defmodule RepositoryHub.Server.Git.RegenerateWebhookSecretAction do
  use RepositoryHub.ServerActionCase, async: true

  alias RepositoryHub.Adapters
  alias RepositoryHub.Server.RegenerateWebhookSecretAction
  alias InternalApi.Repository.RegenerateWebhookSecretResponse
  alias RepositoryHub.{InternalApiFactory, RepositoryModelFactory}
  alias InternalApi

  setup do
    adapter = Adapters.git()
    %{id: repository_id} = RepositoryModelFactory.git_repo()

    {:ok, %{adapter: adapter, repository_id: repository_id}}
  end

  describe "Git RegenerateWebhookSecretAction" do
    test "should create a repository", %{adapter: adapter, repository_id: repository_id} do
      request = InternalApiFactory.regenerate_webhook_secret_request(repository_id: repository_id)

      assert {:ok, %RegenerateWebhookSecretResponse{secret: _repository}} =
               RegenerateWebhookSecretAction.execute(adapter, request)
    end
  end
end
