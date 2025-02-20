defmodule RepositoryHub.Adapters.Github.DescribeRevisionActionTest do
  @moduledoc false
  alias RepositoryHub.Server.DescribeRevisionAction
  use RepositoryHub.ServerActionCase, async: false

  alias RepositoryHub.Adapters
  alias RepositoryHub.RepositoryModelFactory
  alias RepositoryHub.GithubClientFactory
  alias RepositoryHub.InternalApiFactory

  import Mock

  setup do
    [github_repo, githubapp_repo | _other_repos] = RepositoryModelFactory.seed_repositories()

    %{github_repo: github_repo, githubapp_repo: githubapp_repo}
  end

  describe "Github oauth DescribeRevisionAction" do
    setup_with_mocks(GithubClientFactory.mocks(), context) do
      %{
        repository: context[:github_repo],
        adapter: Adapters.github_oauth()
      }
    end

    test "should fetch remote revision data", %{repository: repository, adapter: adapter} do
      assert_described_revision(repository, adapter)
    end
  end

  describe "Github app DescribeRevisionAction" do
    setup_with_mocks(GithubClientFactory.mocks(), context) do
      %{
        repository: context[:githubapp_repo],
        adapter: Adapters.github_app()
      }
    end

    test "should fetch remote revision data", %{repository: repository, adapter: adapter} do
      assert_described_revision(repository, adapter)
    end
  end

  defp assert_described_revision(repository, adapter) do
    request =
      InternalApiFactory.describe_revision_request(
        repository_id: repository.id,
        revision: %{reference: "refs/heads/master", commit_sha: ""}
      )

    assert {:ok, %{commit: commit}} = DescribeRevisionAction.execute(adapter, request)

    assert commit.sha == "1234567"
    assert commit.msg == "Commit message"
    assert commit.author_name == "johndoe"
    assert commit.author_uuid == "1234567"
    assert commit.author_avatar_url == "https://avatars.githubusercontent.com/u/1234567?v=3"
  end
end
