defmodule GithubNotifier.NotifierTest do
  use ExUnit.Case

  alias GithubNotifier.Notifier

  @cache_prefix "ee2e6241-f30b-4892-a0d5-bd900b713430/1234567/1/ci/semaphoreci/push:"
  @pipeline_key "#{@cache_prefix} Pipeline/pending/The build is pending on Semaphore 2.0."

  setup do
    Cachex.clear(:store)
    Cachex.clear(:task_policy)

    :ok
  end

  defp stub_scheduler(commit_status) do
    GrpcMock.stub(
      SchedulerMock,
      :describe,
      struct(InternalApi.PeriodicScheduler.DescribeResponse,
        status: struct(InternalApi.Status, code: :OK),
        periodic:
          struct(InternalApi.PeriodicScheduler.Periodic,
            id: "task-1",
            commit_status: commit_status
          )
      )
    )
  end

  defp stub_scheduler_not_found do
    GrpcMock.stub(
      SchedulerMock,
      :describe,
      struct(InternalApi.PeriodicScheduler.DescribeResponse,
        status: struct(InternalApi.Status, code: :NOT_FOUND)
      )
    )
  end

  defp stub_services(pipeline_opts, project_opts) do
    GrpcMock.stub(RepositoryHubMock, :create_build_status, struct(Google.Protobuf.Empty))

    GrpcMock.stub(
      PipelineMock,
      :describe,
      Support.Factories.pipeline_describe_response(pipeline_opts)
    )

    GrpcMock.stub(
      ProjecthubMock,
      :describe,
      Support.Factories.project_describe_response(:PIPELINE, project_opts)
    )

    GrpcMock.stub(RepoProxyMock, :describe, Support.Factories.repo_proxy_describe_response())

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
  end

  describe ".notify" do
    test "hook triggered pipeline posts a status" do
      stub_services([triggered_by: :HOOK], [])

      Notifier.notify("req-1", "123")

      assert Cachex.get!(:store, @pipeline_key) == true
    end

    test "scheduled pipeline posts by default" do
      stub_services([triggered_by: :SCHEDULE], [])

      Notifier.notify("req-2", "123")

      assert Cachex.get!(:store, @pipeline_key) == true
    end

    test "scheduled pipeline is skipped when the project sets skip_scheduled_run" do
      stub_services([triggered_by: :SCHEDULE], skip_scheduled_run: true)

      assert Notifier.notify("req-3", "123") == nil

      assert Cachex.get!(:store, @pipeline_key) == nil
    end

    test "manually run pipeline posts by default" do
      stub_services([triggered_by: :MANUAL_RUN], [])

      Notifier.notify("req-4", "123")

      assert Cachex.get!(:store, @pipeline_key) == true
    end

    test "manually run pipeline is skipped when the project sets skip_manual_run" do
      stub_services([triggered_by: :MANUAL_RUN], skip_manual_run: true)

      assert Notifier.notify("req-5", "123") == nil

      assert Cachex.get!(:store, @pipeline_key) == nil
    end

    test "rerun of a skipped scheduled pipeline posts a status" do
      stub_services(
        [triggered_by: :SCHEDULE, workflow_rerun_of: "prev-wf-id"],
        skip_scheduled_run: true
      )

      Notifier.notify("req-6", "123")

      assert Cachex.get!(:store, @pipeline_key) == true
    end

    test "task ALWAYS posts even when the project skips scheduled runs" do
      stub_services(
        [triggered_by: :SCHEDULE, wf_triggerer_id: "task-1"],
        skip_scheduled_run: true
      )

      stub_scheduler(:ALWAYS)

      Notifier.notify("req-9", "123")

      assert Cachex.get!(:store, @pipeline_key) == true
    end

    test "task NEVER skips even when the project posts scheduled runs" do
      stub_services([triggered_by: :SCHEDULE, wf_triggerer_id: "task-1"], [])

      stub_scheduler(:NEVER)

      assert Notifier.notify("req-10", "123") == nil

      assert Cachex.get!(:store, @pipeline_key) == nil
    end

    test "a deleted task falls back to the project settings" do
      stub_services(
        [triggered_by: :MANUAL_RUN, wf_triggerer_id: "task-1"],
        skip_manual_run: true
      )

      stub_scheduler_not_found()

      assert Notifier.notify("req-11", "123") == nil

      assert Cachex.get!(:store, @pipeline_key) == nil
    end

    test "hook triggered pipelines never resolve the task" do
      stub_services([triggered_by: :HOOK, wf_triggerer_id: "hook-id"], [])

      GrpcMock.stub(SchedulerMock, :describe, fn _req, _stream ->
        raise "describe must not be called for hook pipelines"
      end)

      Notifier.notify("req-12", "123")

      assert Cachex.get!(:store, @pipeline_key) == true
    end
  end

  describe ".notify_with_summary" do
    test "scheduled pipeline is skipped when the project sets skip_scheduled_run" do
      stub_services([triggered_by: :SCHEDULE], skip_scheduled_run: true)

      assert Notifier.notify_with_summary("req-7", "123") == nil

      assert Cachex.get!(:store, @pipeline_key) == nil
    end

    test "hook triggered pipeline posts a status" do
      stub_services([triggered_by: :HOOK], [])

      GrpcMock.stub(
        VelocityHubMock,
        :list_pipeline_summaries,
        struct(InternalApi.Velocity.ListPipelineSummariesResponse, pipeline_summaries: [])
      )

      Notifier.notify_with_summary("req-8", "123")

      assert Cachex.get!(:store, @pipeline_key) == true
    end
  end
end
