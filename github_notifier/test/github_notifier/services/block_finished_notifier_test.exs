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

      System.delete_env("BLOCK_FINISHED_PREFETCH_COUNT")
      on_exit(fn -> System.delete_env("BLOCK_FINISHED_PREFETCH_COUNT") end)

      :ok
    end

    test "prefetch defaults to 1" do
      assert BlockFinishedNotifier.prefetch_count() == 1
    end

    test "prefetch is read from BLOCK_FINISHED_PREFETCH_COUNT" do
      System.put_env("BLOCK_FINISHED_PREFETCH_COUNT", "5")

      assert BlockFinishedNotifier.prefetch_count() == 5
    end

    test "the prefetch in effect is logged when the consumer starts" do
      System.put_env("BLOCK_FINISHED_PREFETCH_COUNT", "7")

      log =
        ExUnit.CaptureLog.capture_log(fn ->
          assert BlockFinishedNotifier.starting_prefetch_count() == 7
        end)

      assert log =~ "Block finished consumer starting with a prefetch of 7"
    end

    test "prefetch accepts the upper bound" do
      System.put_env("BLOCK_FINISHED_PREFETCH_COUNT", "50")

      assert BlockFinishedNotifier.prefetch_count() == 50
    end

    test "an invalid prefetch falls back to the default" do
      for value <- ["0", "-3", "ten", "5x", "", "51", "100000"] do
        System.put_env("BLOCK_FINISHED_PREFETCH_COUNT", value)

        assert BlockFinishedNotifier.prefetch_count() == 1, "accepted #{inspect(value)}"
      end
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

      test_pid = self()

      GrpcMock.stub(RepoProxyMock, :describe, fn _req, _stream ->
        send(test_pid, :repo_proxy_fetched)
        Support.Factories.repo_proxy_describe_response()
      end)

      assert GithubNotifier.Notifier.notify("asd", "123", "1") == nil

      refute_received {:build_status, _, _, _}
      refute_received :repo_proxy_fetched
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

    test "deliveries from the broker are handled concurrently" do
      {:ok, in_flight} = Agent.start_link(fn -> %{now: 0, max: 0} end)

      GrpcMock.stub(PipelineMock, :describe, fn req, _stream ->
        Agent.update(in_flight, &%{now: &1.now + 1, max: max(&1.max, &1.now + 1)})
        Process.sleep(200)
        Agent.update(in_flight, &%{&1 | now: &1.now - 1})

        response = Support.Factories.pipeline_describe_response()
        %{response | pipeline: %{response.pipeline | ppl_id: req.ppl_id}}
      end)

      System.put_env("BLOCK_FINISHED_PREFETCH_COUNT", "10")
      start_supervised!({BlockFinishedNotifier, [process_name: :concurrent_block_consumer]})

      pipeline_ids =
        for index <- 1..10, do: "broker-#{index}-#{System.unique_integer([:positive])}"

      for pipeline_id <- pipeline_ids do
        Tackle.publish(
          InternalApi.Plumber.PipelineBlockEvent.encode(
            struct(InternalApi.Plumber.PipelineBlockEvent,
              pipeline_id: pipeline_id,
              block_id: "1"
            )
          ),
          %{
            url: Application.get_env(:github_notifier, :amqp_url),
            exchange: "pipeline_block_state_exchange",
            routing_key: "done"
          }
        )
      end

      for pipeline_id <- pipeline_ids do
        assert_receive {:build_status, :PENDING, "ci/semaphoreci/push: Block 1", ^pipeline_id},
                       15_000
      end

      # The application's own consumer may share the queue at a prefetch of 1.
      assert Agent.get(in_flight, & &1.max) >= 5
    end
  end
end
