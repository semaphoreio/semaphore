defmodule RepositoryHub.Server.Git.UpdateActionTest do
  @moduledoc false
  use RepositoryHub.ServerActionCase, async: true

  alias RepositoryHub.Adapters
  alias RepositoryHub.Server.UpdateAction
  alias RepositoryHub.InternalApiFactory
  alias RepositoryHub.RepositoryModelFactory
  alias InternalApi.Repository.UpdateResponse

  setup do
    {:ok, repository} =
      RepositoryModelFactory.create_repository(
        name: "repo",
        owner: "owner",
        provider: "git",
        integration_type: "git",
        url: "ssh://git@git.example.com/owner/repo.git"
      )

    %{adapter: Adapters.git(), repository: repository}
  end

  describe "Git UpdateAction" do
    test "updates the url, pipeline file and whitelist", %{adapter: adapter, repository: repository} do
      request =
        InternalApiFactory.update_request(
          repository_id: repository.id,
          url: "ssh://git@git.example.com:2222/new-owner/new-repo.git",
          pipeline_file: ".semaphore/other.yml",
          whitelist: %InternalApi.Projecthub.Project.Spec.Repository.Whitelist{
            branches: ["main"],
            tags: ["v*"]
          }
        )

      assert {:ok, %UpdateResponse{repository: response}} = UpdateAction.execute(adapter, request)
      assert response.url == "ssh://git@git.example.com:2222/new-owner/new-repo.git"

      {:ok, updated} = RepositoryHub.Model.RepositoryQuery.get_by_id(repository.id)
      assert updated.url == "ssh://git@git.example.com:2222/new-owner/new-repo.git"
      assert updated.owner == "new-owner"
      assert updated.name == "new-repo"
      assert updated.pipeline_file == ".semaphore/other.yml"
      assert updated.whitelist == %{"branches" => ["main"], "tags" => ["v*"]}
    end

    test "refuses a url that is not a Generic Git ssh url", %{adapter: adapter, repository: repository} do
      request =
        InternalApiFactory.update_request(
          repository_id: repository.id,
          url: "https://git.example.com/owner/repo.git"
        )

      assert {:error, _} = UpdateAction.execute(adapter, request)

      {:ok, unchanged} = RepositoryHub.Model.RepositoryQuery.get_by_id(repository.id)
      assert unchanged.url == "ssh://git@git.example.com/owner/repo.git"
    end

    test "fails for an unknown repository", %{adapter: adapter} do
      request =
        InternalApiFactory.update_request(
          repository_id: Ecto.UUID.generate(),
          url: "ssh://git@git.example.com/owner/repo.git"
        )

      assert {:error, _} = UpdateAction.execute(adapter, request)
    end

    test "validates the request", %{adapter: adapter, repository: repository} do
      assert {:ok, _} =
               UpdateAction.validate(
                 adapter,
                 InternalApiFactory.update_request(
                   repository_id: repository.id,
                   url: "ssh://git@git.example.com/owner/repo.git"
                 )
               )

      assert {:error, _} = UpdateAction.validate(adapter, %InternalApi.Repository.UpdateRequest{})

      assert {:error, _} =
               UpdateAction.validate(adapter, InternalApiFactory.update_request(repository_id: repository.id, url: ""))
    end
  end
end
