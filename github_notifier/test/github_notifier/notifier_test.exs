defmodule GithubNotifier.NotifierTest do
  use ExUnit.Case

  @status_key "ee2e6241-f30b-4892-a0d5-bd900b713430/1234567/1/ci/semaphoreci/push: Block 1/pending/The build is pending on Semaphore 2.0."

  setup do
    Cachex.clear(:store)
    Cachex.clear(:task_policy)

    :ok
  end

  describe "notify/3 with a scheduled pipeline" do
    test "asks repository_hub to suppress when the task skips scheduled run notifications" do
      stub_services(triggered_by: :SCHEDULE, wf_triggerer_id: "task-1")

      GrpcMock.stub(
        SchedulerMock,
        :describe,
        Support.Factories.periodic_describe_response(skip_scheduled_run_notifications: true)
      )

      GithubNotifier.Notifier.notify("asd", "123", "1")

      assert_received {:build_status, request}
      assert request.suppress == true
      # guarded: a source_id is what lets repository_hub serialize this check
      assert request.source_id != ""
    end

    test "sends the commit status when the task does not skip them" do
      stub_services(triggered_by: :SCHEDULE, wf_triggerer_id: "task-1")

      GrpcMock.stub(
        SchedulerMock,
        :describe,
        Support.Factories.periodic_describe_response(skip_manual_run_notifications: true)
      )

      GithubNotifier.Notifier.notify("asd", "123", "1")

      assert_received {:build_status, request}
      assert request.suppress == false
      assert Cachex.get!(:store, @status_key) == true
    end

    test "sends the commit status when the task cannot be resolved" do
      stub_services(triggered_by: :SCHEDULE, wf_triggerer_id: "task-1")
      GrpcMock.stub(SchedulerMock, :describe, Support.Factories.periodic_not_found_response())

      GithubNotifier.Notifier.notify("asd", "123", "1")

      assert_received {:build_status, request}
      assert request.suppress == false
      assert Cachex.get!(:store, @status_key) == true
    end

    test "sends the commit status when the scheduler stalls, and caches it as unreachable" do
      stub_services(triggered_by: :SCHEDULE, wf_triggerer_id: "task-1")

      GrpcMock.stub(SchedulerMock, :describe, fn _, _ ->
        Process.sleep(GithubNotifier.Models.Periodic.lookup_budget() * 2)
        Support.Factories.periodic_describe_response(skip_scheduled_run_notifications: true)
      end)

      GithubNotifier.Notifier.notify("asd", "123", "1")

      assert_received {:build_status, request}
      assert request.suppress == false
      assert Cachex.get!(:store, @status_key) == true

      # the RPC deadline must expire before the caller's budget, or the task is
      # killed before it can cache the failure and every later notification
      # pays the full stall again
      assert Cachex.get!(:task_policy, "task-1") == :not_found
    end
  end

  describe "notify/3 across triggers and status levels" do
    test "asks repository_hub to suppress a Run now pipeline when the task skips manual runs" do
      stub_services(triggered_by: :MANUAL_RUN, wf_triggerer_id: "task-1")

      GrpcMock.stub(
        SchedulerMock,
        :describe,
        Support.Factories.periodic_describe_response(skip_manual_run_notifications: true)
      )

      GithubNotifier.Notifier.notify("asd", "123", "1")

      assert_received {:build_status, request}
      assert request.suppress == true
    end

    test "does not suppress a Run now pipeline when only the scheduled flag is set" do
      stub_services(triggered_by: :MANUAL_RUN, wf_triggerer_id: "task-1")

      GrpcMock.stub(
        SchedulerMock,
        :describe,
        Support.Factories.periodic_describe_response(skip_scheduled_run_notifications: true)
      )

      GithubNotifier.Notifier.notify("asd", "123", "1")

      assert_received {:build_status, request}
      assert request.suppress == false
    end

    test "carries the flag onto every status when the project reports block and pipeline level" do
      stub_services(triggered_by: :SCHEDULE, wf_triggerer_id: "task-1")
      GrpcMock.stub(ProjecthubMock, :describe, block_and_pipeline_level_project())

      GrpcMock.stub(
        SchedulerMock,
        :describe,
        Support.Factories.periodic_describe_response(skip_scheduled_run_notifications: true)
      )

      GithubNotifier.Notifier.notify("asd", "123", "1")

      # one status per level; the flag must ride on all of them
      requests = collect_build_statuses()
      assert length(requests) > 1
      assert Enum.all?(requests, & &1.suppress)
    end
  end

  describe "notify_with_summary/2" do
    test "asks repository_hub to suppress when the task skips scheduled run notifications" do
      stub_services(triggered_by: :SCHEDULE, wf_triggerer_id: "task-1")
      stub_summary()

      GrpcMock.stub(
        SchedulerMock,
        :describe,
        Support.Factories.periodic_describe_response(skip_scheduled_run_notifications: true)
      )

      GithubNotifier.Notifier.notify_with_summary("asd", "123")

      assert_received {:build_status, request}
      assert request.suppress == true
    end

    test "does not suppress when the task sends statuses" do
      stub_services(triggered_by: :SCHEDULE, wf_triggerer_id: "task-1")
      stub_summary()
      GrpcMock.stub(SchedulerMock, :describe, Support.Factories.periodic_describe_response())

      GithubNotifier.Notifier.notify_with_summary("asd", "123")

      assert_received {:build_status, request}
      assert request.suppress == false
    end
  end

  describe "notify/3 with a hook pipeline" do
    test "never resolves the task" do
      stub_services(triggered_by: :HOOK)
      GrpcMock.stub(SchedulerMock, :describe, fn _, _ -> raise "should not be called" end)

      GithubNotifier.Notifier.notify("asd", "123", "1")

      assert_received {:build_status, request}
      assert request.suppress == false
      assert Cachex.get!(:store, @status_key) == true
    end
  end

  defp collect_build_statuses(acc \\ []) do
    receive do
      {:build_status, request} -> collect_build_statuses([request | acc])
    after
      0 -> acc
    end
  end

  defp stub_summary do
    GrpcMock.stub(
      VelocityHubMock,
      :list_pipeline_summaries,
      struct(InternalApi.Velocity.ListPipelineSummariesResponse,
        pipeline_summaries: [
          struct(InternalApi.Velocity.PipelineSummary,
            pipeline_id: "123",
            summary:
              struct(InternalApi.Velocity.Summary,
                total: 10,
                passed: 9,
                skipped: 0,
                error: 0,
                failed: 1,
                disabled: 0,
                duration: 100
              )
          )
        ]
      )
    )
  end

  defp block_and_pipeline_level_project do
    alias InternalApi.Projecthub.Project.Spec.Repository

    response = Support.Factories.project_describe_response()
    status = response.project.spec.repository.status
    [file] = status.pipeline_files

    files = [
      file,
      struct(Repository.Status.PipelineFile, path: file.path, level: :PIPELINE)
    ]

    repository = %{response.project.spec.repository | status: %{status | pipeline_files: files}}
    spec = %{response.project.spec | repository: repository}
    %{response | project: %{response.project | spec: spec}}
  end

  defp stub_services(pipeline_opts) do
    test_pid = self()

    GrpcMock.stub(RepositoryHubMock, :create_build_status, fn request, _stream ->
      send(test_pid, {:build_status, request})
      Support.Factories.create_build_status_response()
    end)

    GrpcMock.stub(
      PipelineMock,
      :describe,
      Support.Factories.pipeline_describe_response(pipeline_opts)
    )

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
  end
end
