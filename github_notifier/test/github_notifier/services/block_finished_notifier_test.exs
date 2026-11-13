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

    test "an invalid prefetch falls back to the default" do
      for value <- ["0", "-3", "ten", "5x", ""] do
        System.put_env("BLOCK_FINISHED_PREFETCH_COUNT", value)

        assert BlockFinishedNotifier.prefetch_count() == 1, "accepted #{inspect(value)}"
      end
    end

    test "a block event that read a running pipeline cannot overwrite the terminal pipeline status" do
      {:ok, gate} = Agent.start_link(fn -> %{pipeline_reads: 0, held: nil, release: false} end)

      # The first read sees the pipeline running, every later one sees it done.
      GrpcMock.stub(PipelineMock, :describe, fn _req, _stream ->
        reads = Agent.get_and_update(gate, &{&1.pipeline_reads, bump(&1)})
        state = if reads == 0, do: :RUNNING, else: :DONE
        Support.Factories.pipeline_describe_response(state: state, result: :PASSED)
      end)

      # Holds the first handler after its pipeline read until the second one is done.
      GrpcMock.stub(RepoProxyMock, :describe, fn _req, _stream ->
        if Agent.get_and_update(gate, &hold_first/1), do: wait_for_release(gate)
        Support.Factories.repo_proxy_describe_response()
      end)

      stale = Task.async(fn -> GithubNotifier.Notifier.notify("stale", "123", "1") end)
      wait_until(fn -> Agent.get(gate, & &1.held) end)

      GithubNotifier.Notifier.notify("fresh", "123", "2")
      assert_received {:build_status, :SUCCESS, @pipeline_context, _}

      Agent.update(gate, &%{&1 | release: true})
      Task.await(stale)

      assert_received {:build_status, :PENDING, "ci/semaphoreci/push: Block 1", _}
      refute_received {:build_status, :PENDING, @pipeline_context, _}
    end

    test "deliveries from the broker are handled concurrently" do
      GrpcMock.stub(PipelineMock, :describe, fn req, _stream ->
        response = Support.Factories.pipeline_describe_response()
        %{response | pipeline: %{response.pipeline | ppl_id: req.ppl_id}}
      end)

      System.put_env("BLOCK_FINISHED_PREFETCH_COUNT", "10")
      start_supervised!({BlockFinishedNotifier, [process_name: :concurrent_block_consumer]})

      pipeline_ids =
        for index <- 1..10, do: "broker-#{index}-#{System.unique_integer([:positive])}"

      started_at = System.monotonic_time(:millisecond)

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
        assert_receive {:build_status, :PENDING, @pipeline_context, ^pipeline_id}, 15_000
      end

      # Each delivery waits a second before working, so one at a time takes 10s+.
      assert System.monotonic_time(:millisecond) - started_at < 5_000
    end

    defp bump(gate), do: %{gate | pipeline_reads: gate.pipeline_reads + 1}

    defp hold_first(%{held: nil} = gate), do: {true, %{gate | held: true}}
    defp hold_first(gate), do: {false, gate}

    defp wait_for_release(gate) do
      wait_until(fn -> Agent.get(gate, & &1.release) end)
    end

    defp wait_until(condition, attempts \\ 200) do
      cond do
        condition.() -> :ok
        attempts == 0 -> flunk("condition was not met in time")
        true -> Process.sleep(10) && wait_until(condition, attempts - 1)
      end
    end
  end
end
