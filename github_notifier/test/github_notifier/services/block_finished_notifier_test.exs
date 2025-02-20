defmodule GithubNotifier.Services.BlockFinishedNotifierTest do
  require GrpcMock
  use ExUnit.Case

  setup do
    Cachex.clear(:store)

    :ok
  end

  describe ".handle_message" do
    test "message processing when the server is avaible" do
      Cachex.clear(:store)

      GrpcMock.stub(RepositoryHubMock, :create_build_status, Google.Protobuf.Empty.new())

      GrpcMock.stub(PipelineMock, :describe, Support.Factories.pipeline_describe_response())
      GrpcMock.stub(RepoProxyMock, :describe, Support.Factories.repo_proxy_describe_response())
      GrpcMock.stub(ProjecthubMock, :describe, Support.Factories.project_describe_response())

      GrpcMock.stub(
        UserMock,
        :describe,
        InternalApi.User.DescribeResponse.new(
          status: Support.Factories.status_ok(),
          github_token: "github_token"
        )
      )

      GrpcMock.stub(
        OrganizationMock,
        :describe,
        InternalApi.Organization.DescribeResponse.new(
          status: Support.Factories.status_ok(),
          organization:
            InternalApi.Organization.Organization.new(
              org_username: "renderedtext",
              org_id: "123"
            )
        )
      )

      GithubNotifier.Notifier.notify("asd", "123", "1")

      key =
        "ee2e6241-f30b-4892-a0d5-bd900b713430/1234567/1/ci/semaphoreci/push: Block 1/pending/The build is pending on Semaphore 2.0."

      assert Cachex.get!(:store, key) == true
    end

    test "message processing when there is a duplication" do
      Cachex.clear(:store)

      GrpcMock.stub(PipelineMock, :describe, Support.Factories.pipeline_describe_response())
      GrpcMock.stub(RepoProxyMock, :describe, Support.Factories.repo_proxy_describe_response())
      GrpcMock.stub(ProjecthubMock, :describe, Support.Factories.project_describe_response())

      GrpcMock.stub(
        UserMock,
        :describe,
        InternalApi.User.DescribeResponse.new(
          status: Support.Factories.status_ok(),
          github_token: "github_token"
        )
      )

      GrpcMock.stub(
        OrganizationMock,
        :describe,
        InternalApi.Organization.DescribeResponse.new(
          status: Support.Factories.status_ok(),
          organization:
            InternalApi.Organization.Organization.new(
              org_username: "renderedtext",
              org_id: "123"
            )
        )
      )

      Cachex.put!(:store, "renderedtext/github_notifier/1234567/1/Block 1/pending", true)

      GithubNotifier.Notifier.notify("asd", "123", "1")

      key = "renderedtext/github_notifier-1234567-Block 1"
      key = Base.encode16(:erlang.md5(key), case: :lower)

      assert Cachex.get!(:store, key) == nil
    end
  end
end
