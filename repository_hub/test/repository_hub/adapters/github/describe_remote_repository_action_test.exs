defmodule RepositoryHub.Github.DescribeRemoteRepositoryActionTest do
  @moduledoc false
  use RepositoryHub.ServerActionCase, async: false

  alias RepositoryHub.Adapters
  alias RepositoryHub.Server.DescribeRemoteRepositoryAction
  alias RepositoryHub.GithubClientFactory
  alias RepositoryHub.InternalApiFactory

  import Mock

  describe "Github oauth DescribeRemoteRepositoryAction" do
    setup_with_mocks(GithubClientFactory.mocks()) do
      %{
        adapter: Adapters.github_oauth()
      }
    end

    test "should fetch remote repository data", %{adapter: adapter} do
      request = InternalApiFactory.describe_remote_repository_request(integration_type: :GITHUB_OAUTH_TOKEN)

      assert {:ok, %{remote_repository: remote_repository}} = DescribeRemoteRepositoryAction.execute(adapter, request)

      assert remote_repository.id == "12345"
    end
  end
end
