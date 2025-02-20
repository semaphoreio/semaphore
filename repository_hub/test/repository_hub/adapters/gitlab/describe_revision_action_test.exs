defmodule RepositoryHub.Server.GitLab.DescribeRevisionActionTest do
  @moduledoc false
  use RepositoryHub.ServerActionCase, async: false

  alias RepositoryHub.Adapters
  alias RepositoryHub.Server.DescribeRevisionAction
  alias RepositoryHub.InternalApiFactory
  alias InternalApi

  alias RepositoryHub.{
    GitlabClientFactory,
    RepositoryModelFactory
  }

  alias InternalApi.Repository.DescribeRevisionResponse
  import Mock

  setup_with_mocks(GitlabClientFactory.mocks()) do
    %{gitlab_adapter: Adapters.gitlab()}
  end

  describe "GitLab DescribeRevisionAction" do
    test "should describe revision", %{gitlab_adapter: adapter} do
      {:ok, repository} =
        RepositoryModelFactory.create_repository(
          name: "semaphoreci",
          owner: "repositoryhub"
        )

      request =
        InternalApiFactory.describe_revision_request(
          repository_id: repository.id,
          revision: InternalApiFactory.revision()
        )

      assert {:ok, %DescribeRevisionResponse{commit: commit}} = DescribeRevisionAction.execute(adapter, request)

      assert commit.sha != nil
      assert commit.author_name != nil
      assert commit.msg != nil
      assert commit.author_uuid != nil
      assert commit.author_avatar_url != nil
    end

    test "should fail with invalid repository id", %{gitlab_adapter: adapter} do
      request =
        InternalApiFactory.describe_revision_request(
          repository_id: Ecto.UUID.generate(),
          revision: InternalApiFactory.revision()
        )

      assert {:error, _} = DescribeRevisionAction.execute(adapter, request)
    end

    test "should validate required fields", %{gitlab_adapter: adapter} do
      request = %InternalApi.Repository.DescribeRevisionRequest{}

      assert {:error, _} = DescribeRevisionAction.validate(adapter, request)
    end
  end
end
