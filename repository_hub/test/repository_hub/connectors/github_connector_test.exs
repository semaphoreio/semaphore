defmodule RepositoryHub.GithubConnectorTest do
  use RepositoryHub.Case, async: false
  alias RepositoryHub.GithubConnector

  alias RepositoryHub.RepositoryModelFactory

  doctest GithubConnector

  @moduletag :wip
  setup do
    {:ok, repository} =
      RepositoryModelFactory.create_repository(
        url: "git@github.com:dummy/repository.git",
        name: "repository",
        owner: "dummy"
      )

    [
      repository: repository
    ]
  end

  describe "GithubConnector initialization" do
    test "should be able to setup", %{repository: repository} do
      result =
        RepositoryHub.GithubConnector.setup(
          repository.id,
          "token"
        )

      assert {:ok, connector} = result
      assert connector.repository == repository
      assert connector.token == "token"
      assert connector.git_repository.ssh_git_url == connector.repository.url
    end
  end
end
