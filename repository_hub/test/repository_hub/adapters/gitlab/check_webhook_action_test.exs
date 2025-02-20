defmodule RepositoryHub.Server.GitLab.CheckWebhookActionTest do
  @moduledoc false
  use RepositoryHub.ServerActionCase, async: false

  alias RepositoryHub.Adapters
  alias RepositoryHub.Server.CheckWebhookAction
  alias RepositoryHub.InternalApiFactory
  alias InternalApi

  alias RepositoryHub.{
    GitlabClientFactory,
    RepositoryModelFactory
  }

  alias InternalApi.Repository.CheckWebhookResponse
  import Mock

  setup_with_mocks(GitlabClientFactory.mocks()) do
    %{gitlab_adapter: Adapters.gitlab()}
  end

  describe "GitLab CheckWebhookAction" do
    test "should fail if webhook doesn't exist", %{gitlab_adapter: adapter} do
      {:ok, repository} =
        RepositoryModelFactory.create_repository(
          name: "semaphoreci",
          owner: "repositoryhub",
          hook_id: "nothing"
        )

      request = InternalApiFactory.check_webhook_request(repository_id: repository.id)

      assert {:error, _} = CheckWebhookAction.execute(adapter, request)
    end

    test "should check webhook if it exists", %{gitlab_adapter: adapter} do
      {:ok, repository} =
        RepositoryModelFactory.create_repository(
          name: "semaphoreci",
          owner: "repositoryhub"
        )

      request = InternalApiFactory.check_webhook_request(repository_id: repository.id)

      assert {:ok, %CheckWebhookResponse{}} = CheckWebhookAction.execute(adapter, request)
    end
  end
end
