defmodule RepositoryHub.GithubAdapterTest do
  use ExUnit.Case, async: false

  alias RepositoryHub.{
    GithubAdapter,
    Model,
    RepositoryIntegratorClient
  }

  import Mock

  doctest GithubAdapter

  test "token/3 passes repository remote_id for github app integration" do
    adapter = GithubAdapter.new("github_app")
    {:ok, git_repository} = Model.GitRepository.new("git@github.com:dummy/repository.git", "repo-remote-id-123")

    with_mock RepositoryIntegratorClient, [:passthrough],
      get_token: fn _integration_type, _repository_slug, _repository_remote_id ->
        {:ok, "github-app-token"}
      end do
      assert {:ok, "github-app-token"} = GithubAdapter.token(adapter, Ecto.UUID.generate(), git_repository)

      assert_called(
        RepositoryIntegratorClient.get_token(
          :GITHUB_APP,
          "dummy/repository",
          "repo-remote-id-123"
        )
      )
    end
  end

  test "token/3 passes empty remote_id for github app integration when missing" do
    adapter = GithubAdapter.new("github_app")
    {:ok, git_repository} = Model.GitRepository.new("git@github.com:dummy/repository.git")

    with_mock RepositoryIntegratorClient, [:passthrough],
      get_token: fn _integration_type, _repository_slug, _repository_remote_id ->
        {:ok, "github-app-token"}
      end do
      assert {:ok, "github-app-token"} = GithubAdapter.token(adapter, Ecto.UUID.generate(), git_repository)

      assert_called(
        RepositoryIntegratorClient.get_token(
          :GITHUB_APP,
          "dummy/repository",
          ""
        )
      )
    end
  end
end
