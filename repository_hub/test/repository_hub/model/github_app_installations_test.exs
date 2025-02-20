defmodule RepositoryHub.Model.GithubAppQueryTest do
  use ExUnit.Case, async: true

  alias RepositoryHub.GithubAppFactory
  alias RepositoryHub.Repo
  alias RepositoryHub.Model.GithubAppQuery

  doctest GithubAppQuery

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)

    {:ok, _} = GithubAppFactory.create_collaborator(r_name: "robot/repository-1")
    {:ok, _} = GithubAppFactory.create_collaborator(r_name: "robot/repository-2")
    {:ok, _} = GithubAppFactory.create_collaborator(r_name: "robot/repository-3")
    {:ok, _} = GithubAppFactory.create_collaborator(c_id: 2, r_name: "robot/repository-3")
    {:ok, _} = GithubAppFactory.create_collaborator(c_id: 3, r_name: "robot/repository-3")

    :ok
  end

  describe "#{GithubAppQuery}.list_repositories" do
    test "fetches correct repositories by github_id" do
      repositories = GithubAppQuery.list_repositories([1])
      assert length(repositories) == 3
      assert Enum.all?(repositories, &(&1.c_id == 1)) == true

      repositories = GithubAppQuery.list_repositories([2])
      assert length(repositories) == 1
      assert Enum.all?(repositories, &(&1.c_id == 2)) == true

      repositories = GithubAppQuery.list_repositories([3])
      assert length(repositories) == 1
      assert Enum.all?(repositories, &(&1.c_id == 3)) == true
    end
  end
end
