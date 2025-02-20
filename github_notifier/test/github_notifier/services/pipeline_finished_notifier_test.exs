defmodule GithubNotifier.Services.PipelineFinishedNotifierTest do
  require GrpcMock
  use ExUnit.Case

  setup do
    Cachex.clear(:store)

    :ok
  end

  describe ".handle_message" do
    test "when block level => report each block" do
      Cachex.clear(:store)

      GrpcMock.stub(RepositoryHubMock, :create_build_status, Google.Protobuf.Empty.new())

      GrpcMock.stub(PipelineMock, :describe, Support.Factories.pipeline_describe_response())

      GrpcMock.stub(
        ProjecthubMock,
        :describe,
        Support.Factories.project_describe_response(:BLOCK)
      )

      GrpcMock.stub(RepoProxyMock, :describe, Support.Factories.repo_proxy_describe_response())

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

      GithubNotifier.Notifier.notify("asd", "123")
      cache_prefix = "ee2e6241-f30b-4892-a0d5-bd900b713430/1234567/1/ci/semaphoreci/push:"

      assert Cachex.get!(
               :store,
               "#{cache_prefix} Pipeline/pending"
             ) == nil

      assert Cachex.get!(
               :store,
               "#{cache_prefix} Block 1/pending/The build is pending on Semaphore 2.0."
             ) ==
               true

      assert Cachex.get!(
               :store,
               "#{cache_prefix} Block 2/pending/The build is pending on Semaphore 2.0."
             ) ==
               true

      assert Cachex.get!(
               :store,
               "#{cache_prefix} Block 3/pending/The build is pending on Semaphore 2.0."
             ) ==
               true
    end

    test "when pipeline level => report only pipeline" do
      Cachex.clear(:store)

      GrpcMock.stub(RepositoryHubMock, :create_build_status, Google.Protobuf.Empty.new())

      GrpcMock.stub(PipelineMock, :describe, Support.Factories.pipeline_describe_response())

      GrpcMock.stub(
        ProjecthubMock,
        :describe,
        Support.Factories.project_describe_response(:PIPELINE)
      )

      GrpcMock.stub(RepoProxyMock, :describe, Support.Factories.repo_proxy_describe_response())

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

      GithubNotifier.Notifier.notify("asd", "123")

      cache_prefix = "ee2e6241-f30b-4892-a0d5-bd900b713430/1234567/1/ci/semaphoreci/push:"

      assert Cachex.get!(
               :store,
               "#{cache_prefix} Pipeline/pending/The build is pending on Semaphore 2.0."
             ) == true

      assert Cachex.get!(
               :store,
               "#{cache_prefix} Block 1/pending/The build is pending on Semaphore 2.0."
             ) ==
               nil

      assert Cachex.get!(
               :store,
               "#{cache_prefix} Block 2/pending/The build is pending on Semaphore 2.0."
             ) ==
               nil

      assert Cachex.get!(
               :store,
               "#{cache_prefix} Block 3/pending/The build is pending on Semaphore 2.0."
             ) ==
               nil
    end

    test "when empty status => do not report" do
      Cachex.clear(:store)

      GrpcMock.stub(RepositoryHubMock, :create_build_status, Google.Protobuf.Empty.new())

      GrpcMock.stub(PipelineMock, :describe, Support.Factories.pipeline_describe_response())

      GrpcMock.stub(
        ProjecthubMock,
        :describe,
        Support.Factories.project_empty_status_describe_response()
      )

      GrpcMock.stub(RepoProxyMock, :describe, Support.Factories.repo_proxy_describe_response())

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

      GithubNotifier.Notifier.notify("asd", "123")

      assert Cachex.get!(
               :store,
               "ee2e6241-f30b-4892-a0d5-bd900b713430/1234567/1/Pipeline/pending"
             ) == nil

      assert Cachex.get!(:store, "ee2e6241-f30b-4892-a0d5-bd900b713430/1234567/1/Block 1/pending") ==
               nil

      assert Cachex.get!(:store, "ee2e6241-f30b-4892-a0d5-bd900b713430/1234567/1/Block 2/pending") ==
               nil

      assert Cachex.get!(:store, "ee2e6241-f30b-4892-a0d5-bd900b713430/1234567/1/Block 3/pending") ==
               nil
    end

    test "when no maching status => do not report" do
      Cachex.clear(:store)

      GrpcMock.stub(RepositoryHubMock, :create_build_status, Google.Protobuf.Empty.new())

      GrpcMock.stub(
        PipelineMock,
        :describe,
        Support.Factories.pipeline_describe_response([], ".semaphore", "foo.yml")
      )

      GrpcMock.stub(
        ProjecthubMock,
        :describe,
        Support.Factories.project_describe_response(:BLOCK)
      )

      GrpcMock.stub(RepoProxyMock, :describe, Support.Factories.repo_proxy_describe_response())

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

      GithubNotifier.Notifier.notify("asd", "123")

      assert Cachex.get!(
               :store,
               "ee2e6241-f30b-4892-a0d5-bd900b713430/1234567/1/Pipeline/pending"
             ) == nil

      assert Cachex.get!(:store, "ee2e6241-f30b-4892-a0d5-bd900b713430/1234567/1/Block 1/pending") ==
               nil

      assert Cachex.get!(:store, "ee2e6241-f30b-4892-a0d5-bd900b713430/1234567/1/Block 2/pending") ==
               nil

      assert Cachex.get!(:store, "ee2e6241-f30b-4892-a0d5-bd900b713430/1234567/1/Block 3/pending") ==
               nil
    end
  end
end
