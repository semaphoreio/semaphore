defmodule RepositoryHub.Server.Gitlab.UpdateActionTest do
  @moduledoc false
  use RepositoryHub.ServerActionCase, async: false

  alias RepositoryHub.Adapters
  alias RepositoryHub.Server.UpdateAction
  alias RepositoryHub.InternalApiFactory
  alias InternalApi

  alias RepositoryHub.{
    GitlabClientFactory,
    RepositoryModelFactory
  }

  alias InternalApi.Repository.UpdateResponse
  import Mock

  setup_with_mocks(GitlabClientFactory.mocks()) do
    %{gitlab_adapter: Adapters.gitlab()}
  end

  describe "Gitlab UpdateAction" do
    test "should update repository", %{gitlab_adapter: adapter} do
      {:ok, repository} =
        RepositoryModelFactory.create_repository(
          name: "semaphoreci",
          owner: "repositoryhub",
          provider: "gitlab",
          url: "git@gitlab.com:dummy/repository.git"
        )

      request =
        InternalApiFactory.update_request(
          repository_id: repository.id,
          url: "git@gitlab.com:dummy/repository-fork.git",
          pipeline_file: ".semaphore/semaphore-2.yml",
          whitelist: %InternalApi.Projecthub.Project.Spec.Repository.Whitelist{
            branches: ["main", "develop"],
            tags: ["v*"]
          }
        )

      assert {:ok, %UpdateResponse{}} = UpdateAction.execute(adapter, request)

      {:ok, updated_repository} = RepositoryHub.Model.RepositoryQuery.get_by_id(repository.id)
      assert updated_repository.pipeline_file == ".semaphore/semaphore-2.yml"

      assert updated_repository.whitelist == %{
               "branches" => ["main", "develop"],
               "tags" => ["v*"]
             }
    end

    test "should fail with invalid repository id", %{gitlab_adapter: adapter} do
      request =
        InternalApiFactory.update_request(
          repository_id: Ecto.UUID.generate(),
          pipeline_file: ".semaphore/semaphore.yml",
          commit_status: "required",
          whitelist: %{}
        )

      assert {:error, _} = UpdateAction.execute(adapter, request)
    end

    test "should validate required fields", %{gitlab_adapter: adapter} do
      request = %InternalApi.Repository.UpdateRequest{}

      assert {:error, _} = UpdateAction.validate(adapter, request)
    end
  end
end
