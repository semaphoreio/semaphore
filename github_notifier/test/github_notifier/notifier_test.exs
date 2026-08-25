defmodule GithubNotifier.NotifierTest do
  use ExUnit.Case

  @status_key "ee2e6241-f30b-4892-a0d5-bd900b713430/1234567/1/ci/semaphoreci/push: Block 1/pending/The build is pending on Semaphore 2.0."

  setup do
    Cachex.clear(:store)
    Cachex.clear(:task_policy)

    :ok
  end

  describe "notify/3 with a scheduled pipeline" do
    test "skips the commit status when the task skips scheduled run notifications" do
      stub_services(triggered_by: :SCHEDULE, wf_triggerer_id: "task-1")

      GrpcMock.stub(
        SchedulerMock,
        :describe,
        Support.Factories.periodic_describe_response(skip_scheduled_run_notifications: true)
      )

      GithubNotifier.Notifier.notify("asd", "123", "1")

      assert Cachex.get!(:store, @status_key) == nil
    end

    test "sends the commit status when the task does not skip them" do
      stub_services(triggered_by: :SCHEDULE, wf_triggerer_id: "task-1")

      GrpcMock.stub(
        SchedulerMock,
        :describe,
        Support.Factories.periodic_describe_response(skip_manual_run_notifications: true)
      )

      GithubNotifier.Notifier.notify("asd", "123", "1")

      assert Cachex.get!(:store, @status_key) == true
    end

    test "sends the commit status when the task cannot be resolved" do
      stub_services(triggered_by: :SCHEDULE, wf_triggerer_id: "task-1")
      GrpcMock.stub(SchedulerMock, :describe, Support.Factories.periodic_not_found_response())

      GithubNotifier.Notifier.notify("asd", "123", "1")

      assert Cachex.get!(:store, @status_key) == true
    end

    test "sends the commit status when the scheduler stalls past the lookup budget" do
      stub_services(triggered_by: :SCHEDULE, wf_triggerer_id: "task-1")

      GrpcMock.stub(SchedulerMock, :describe, fn _, _ ->
        Process.sleep(4_000)
        Support.Factories.periodic_describe_response(skip_scheduled_run_notifications: true)
      end)

      GithubNotifier.Notifier.notify("asd", "123", "1")

      assert Cachex.get!(:store, @status_key) == true
    end
  end

  describe "notify/3 with a hook pipeline" do
    test "never resolves the task" do
      stub_services(triggered_by: :HOOK)
      GrpcMock.stub(SchedulerMock, :describe, fn _, _ -> raise "should not be called" end)

      GithubNotifier.Notifier.notify("asd", "123", "1")

      assert Cachex.get!(:store, @status_key) == true
    end
  end

  defp stub_services(pipeline_opts) do
    GrpcMock.stub(
      RepositoryHubMock,
      :create_build_status,
      Support.Factories.create_build_status_response()
    )

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
