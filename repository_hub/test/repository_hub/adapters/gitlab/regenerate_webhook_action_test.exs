defmodule RepositoryHub.Server.GitLab.RegenerateWebhookActionTest do
  @moduledoc false
  use RepositoryHub.ServerActionCase, async: false

  alias RepositoryHub.Adapters
  alias RepositoryHub.Server.RegenerateWebhookAction
  alias RepositoryHub.InternalApiFactory
  alias InternalApi

  alias RepositoryHub.{
    GitlabClientFactory,
    RepositoryModelFactory
  }

  alias InternalApi.Repository.RegenerateWebhookResponse
  import Mock

  setup_with_mocks(GitlabClientFactory.mocks()) do
    %{gitlab_adapter: Adapters.gitlab()}
  end

  describe "GitLab RegenerateWebhookAction" do
    test "should regenerate webhook", %{gitlab_adapter: adapter} do
      hook_id = Ecto.UUID.generate()

      {:ok, repository} =
        RepositoryModelFactory.create_repository(
          name: "semaphoreci",
          owner: "repositoryhub",
          hook_id: hook_id
        )

      request =
        InternalApiFactory.regenerate_webhook_request(
          repository_id: repository.id,
          url: "https://semaphoreci.com/hooks/gitlab",
          secret: "webhook-secret"
        )

      assert {:ok, %RegenerateWebhookResponse{}} = RegenerateWebhookAction.execute(adapter, request)
    end

    test "should validate required fields", %{gitlab_adapter: adapter} do
      request = %InternalApi.Repository.RegenerateWebhookRequest{}

      assert {:error, _} = RegenerateWebhookAction.validate(adapter, request)
    end
  end
end
