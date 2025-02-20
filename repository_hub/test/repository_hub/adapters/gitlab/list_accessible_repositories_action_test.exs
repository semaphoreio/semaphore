defmodule RepositoryHub.Server.GitLab.ListAccessibleRepositoriesActionTest do
  @moduledoc false
  use RepositoryHub.ServerActionCase, async: false

  alias RepositoryHub.Adapters
  alias RepositoryHub.Server.ListAccessibleRepositoriesAction
  alias RepositoryHub.InternalApiFactory
  alias InternalApi

  alias RepositoryHub.GitlabClientFactory

  alias InternalApi.Repository.ListAccessibleRepositoriesResponse
  import Mock

  setup_with_mocks(GitlabClientFactory.mocks()) do
    %{gitlab_adapter: Adapters.gitlab()}
  end

  describe "GitLab ListAccessibleRepositoriesAction" do
    test "should list accessible repositories", %{gitlab_adapter: adapter} do
      request =
        InternalApiFactory.list_accessible_repositories_request(
          user_id: Ecto.UUID.generate(),
          integration_type: :GITLAB
        )

      assert {:ok, %ListAccessibleRepositoriesResponse{} = response} =
               ListAccessibleRepositoriesAction.execute(adapter, request)

      assert length(response.repositories) > 0
      repository = hd(response.repositories)
      assert repository.name != nil
      assert repository.url != nil
    end

    test "should handle empty repositories list", %{gitlab_adapter: adapter} do
      request =
        InternalApiFactory.list_accessible_repositories_request(
          user_id: Ecto.UUID.generate(),
          integration_type: :GITLAB,
          page_token: "empty"
        )

      assert {:ok, %ListAccessibleRepositoriesResponse{} = response} =
               ListAccessibleRepositoriesAction.execute(adapter, request)

      assert response.repositories == []
    end

    test "should validate required fields", %{gitlab_adapter: adapter} do
      request = %InternalApi.Repository.ListAccessibleRepositoriesRequest{}

      assert {:error, _} = ListAccessibleRepositoriesAction.validate(adapter, request)
    end

    test "should validate pagination parameters", %{gitlab_adapter: adapter} do
      request =
        InternalApiFactory.list_accessible_repositories_request(
          user_id: Ecto.UUID.generate(),
          integration_type: :GITLAB,
          page_token: 123
        )

      assert {:error, _} = ListAccessibleRepositoriesAction.validate(adapter, request)
    end
  end
end
