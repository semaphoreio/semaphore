defmodule RepositoryHub.Server.GitLab.ListCollaboratorsActionTest do
  @moduledoc false
  use RepositoryHub.ServerActionCase, async: false

  alias RepositoryHub.Adapters
  alias RepositoryHub.Server.ListCollaboratorsAction
  alias RepositoryHub.InternalApiFactory
  alias InternalApi

  alias RepositoryHub.{
    GitlabClientFactory,
    RepositoryModelFactory
  }

  alias InternalApi.Repository.ListCollaboratorsResponse
  import Mock

  setup_with_mocks(GitlabClientFactory.mocks()) do
    %{gitlab_adapter: Adapters.gitlab()}
  end

  describe "GitLab ListCollaboratorsAction" do
    test "should list collaborators", %{gitlab_adapter: adapter} do
      {:ok, repository} = RepositoryModelFactory.create_repository(remote_id: Ecto.UUID.generate())

      request = InternalApiFactory.list_collaborators_request(repository_id: repository.id)

      assert {:ok, %ListCollaboratorsResponse{} = response} = ListCollaboratorsAction.execute(adapter, request, nil)

      assert length(response.collaborators) > 0
      collaborator = hd(response.collaborators)
      assert collaborator.login != nil
      assert collaborator.permission != nil
    end

    test "should handle repository without collaborators", %{gitlab_adapter: adapter} do
      {:ok, repository} = RepositoryModelFactory.create_repository(remote_id: "empty-repo")

      request = InternalApiFactory.list_collaborators_request(repository_id: repository.id)

      assert {:ok, %ListCollaboratorsResponse{} = response} = ListCollaboratorsAction.execute(adapter, request, nil)

      assert response.collaborators == []
    end

    test "should fail with invalid repository id", %{gitlab_adapter: adapter} do
      request = InternalApiFactory.list_collaborators_request(repository_id: Ecto.UUID.generate())

      assert {:error, _} = ListCollaboratorsAction.execute(adapter, request, nil)
    end

    test "should validate required fields", %{gitlab_adapter: adapter} do
      request = %InternalApi.Repository.ListCollaboratorsRequest{}

      assert {:error, _} = ListCollaboratorsAction.validate(adapter, request)
    end
  end
end
