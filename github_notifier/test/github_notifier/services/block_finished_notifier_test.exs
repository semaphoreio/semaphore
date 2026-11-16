defmodule GithubNotifier.Services.BlockFinishedNotifierTest do
  use ExUnit.Case

  alias GithubNotifier.Services.BlockFinishedNotifier

  setup do
    Cachex.clear(:store)

    :ok
  end

  describe ".handle_message" do
    test "message processing when the server is avaible" do
      Cachex.clear(:store)

      GrpcMock.stub(
        RepositoryHubMock,
        :create_build_status,
        Support.Factories.create_build_status_response()
      )

      GrpcMock.stub(PipelineMock, :describe, Support.Factories.pipeline_describe_response())
      GrpcMock.stub(RepoProxyMock, :describe, Support.Factories.repo_proxy_describe_response())
      GrpcMock.stub(ProjecthubMock, :describe, Support.Factories.project_describe_response())

      GrpcMock.stub(
        UserMock,
        :describe,
        struct(InternalApi.User.DescribeResponse,
          status: Support.Factories.status_ok(),
          github_token: "github_token"
        )
      )

      GrpcMock.stub(
        OrganizationMock,
        :describe,
        struct(InternalApi.Organization.DescribeResponse,
          status: Support.Factories.status_ok(),
          organization:
            struct(InternalApi.Organization.Organization,
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

      GrpcMock.stub(
        RepositoryHubMock,
        :create_build_status,
        Support.Factories.create_build_status_response()
      )

      GrpcMock.stub(PipelineMock, :describe, Support.Factories.pipeline_describe_response())
      GrpcMock.stub(RepoProxyMock, :describe, Support.Factories.repo_proxy_describe_response())
      GrpcMock.stub(ProjecthubMock, :describe, Support.Factories.project_describe_response())

      GrpcMock.stub(
        UserMock,
        :describe,
        struct(InternalApi.User.DescribeResponse,
          status: Support.Factories.status_ok(),
          github_token: "github_token"
        )
      )

      GrpcMock.stub(
        OrganizationMock,
        :describe,
        struct(InternalApi.Organization.DescribeResponse,
          status: Support.Factories.status_ok(),
          organization:
            struct(InternalApi.Organization.Organization,
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

  describe "concurrent consumption" do
    @pipeline_context "ci/semaphoreci/push: Pipeline"

    setup do
      test_pid = self()

      GrpcMock.stub(RepositoryHubMock, :create_build_status, fn req, _stream ->
        send(test_pid, {:build_status, req.status, req.context, req.source_id})
        Support.Factories.create_build_status_response()
      end)

      GrpcMock.stub(RepoProxyMock, :describe, Support.Factories.repo_proxy_describe_response())

      GrpcMock.stub(
        ProjecthubMock,
        :describe,
        Support.Factories.project_describe_response([:BLOCK, :PIPELINE])
      )

      GrpcMock.stub(
        OrganizationMock,
        :describe,
        Support.Factories.organization_describe_response()
      )

      :ok
    end

    test "a block event reports its block and leaves the pipeline status alone" do
      GrpcMock.stub(PipelineMock, :describe, Support.Factories.pipeline_describe_response())

      GithubNotifier.Notifier.notify("asd", "123", "1")

      assert_received {:build_status, :PENDING, "ci/semaphoreci/push: Block 1", _}
      refute_received {:build_status, _, _, _}
    end

    test "a block event sends nothing when the project reports only the pipeline level" do
      GrpcMock.stub(PipelineMock, :describe, Support.Factories.pipeline_describe_response())

      GrpcMock.stub(
        ProjecthubMock,
        :describe,
        Support.Factories.project_describe_response(:PIPELINE)
      )

      assert GithubNotifier.Notifier.notify("asd", "123", "1") == nil

      refute_received {:build_status, _, _, _}
    end

    test "a pipeline event still reports every block and the pipeline" do
      GrpcMock.stub(PipelineMock, :describe, Support.Factories.pipeline_describe_response())

      GithubNotifier.Notifier.notify("asd", "123")

      assert_received {:build_status, _, "ci/semaphoreci/push: Block 1", _}
      assert_received {:build_status, _, @pipeline_context, _}
    end

    test "handle_message reports the block status" do
      GrpcMock.stub(PipelineMock, :describe, Support.Factories.pipeline_describe_response())

      message =
        InternalApi.Plumber.PipelineBlockEvent.encode(
          struct(InternalApi.Plumber.PipelineBlockEvent, pipeline_id: "123", block_id: "1")
        )

      BlockFinishedNotifier.handle_message(message)

      assert_received {:build_status, :PENDING, "ci/semaphoreci/push: Block 1", _}
    end
  end
end
