defmodule Zebra.Workers.JobRequestFactory.RepoProxyTest do
  alias Support.Factories
  use Zebra.DataCase

  alias Zebra.Workers.JobRequestFactory.RepoProxy

  @hook InternalApi.RepoProxy.Hook.new(
          hook_id: "",
          head_commit_sha: "8d762d04c7c753c2181030a9385b496559e5a885",
          commit_message: "",
          commit_range: "123...456",
          repo_host_url: "",
          repo_host_username: "",
          repo_host_email: "",
          repo_host_avatar_url: "",
          user_id: "",
          semaphore_email: "",
          repo_slug: "test-org/test-repo",
          git_ref: "refs/heads/master",
          git_ref_type: InternalApi.RepoProxy.Hook.Type.value(:BRANCH),
          pr_slug: "",
          pr_name: "",
          pr_number: "",
          pr_sha: "",
          tag_name: "",
          branch_name: "master",
          pr_mergeable: false,
          pr_branch_name: ""
        )

  describe ".extract_hook_id" do
    test "when project_debug_job => returns nil" do
      {:ok, job} = Support.Factories.Job.create(:pending, %{build_id: nil})

      assert RepoProxy.extract_hook_id(job, :project_debug_job) == {:ok, nil}
    end

    test "when pipeline_job without build_id => returns stop_job_processing" do
      {:ok, job} = Support.Factories.Job.create(:pending, %{build_id: nil})

      assert RepoProxy.extract_hook_id(job, :pipeline_job) ==
               {:stop_job_processing, "Job #{job.id} is missing build_id"}
    end

    test "when build is missing for pipeline_job => returns stop_job_processing" do
      {:ok, job} = Support.Factories.Job.create(:pending)

      assert RepoProxy.extract_hook_id(job, :pipeline_job) ==
               {:stop_job_processing, "Build #{job.build_id} not found"}
    end

    test "for pipeline_job => returns hook_id" do
      {:ok, task} = Support.Factories.Task.create()
      {:ok, job} = Support.Factories.Job.create(:pending, %{build_id: task.id})

      assert RepoProxy.extract_hook_id(job, :pipeline_job) == {:ok, task.hook_id}
    end

    test "when debug is missing for debug job => returns stop_job_processing" do
      {:ok, job} = Support.Factories.Job.create(:pending, %{build_id: nil})

      assert RepoProxy.extract_hook_id(job, :debug_job) ==
               {:stop_job_processing, "Debug record for job #{job.id} not found"}
    end

    test "when debugged job is missing for debug job => returns stop_job_processing" do
      {:ok, job} = Support.Factories.Job.create(:pending, %{build_id: nil})
      {:ok, debug} = Support.Factories.Debug.create_for_job(nil, job.id)

      assert RepoProxy.extract_hook_id(job, :debug_job) ==
               {:stop_job_processing, "Debugged job #{debug.debugged_id} not found"}
    end

    test "for debug job => returns hook_id" do
      {:ok, task} = Support.Factories.Task.create()
      {:ok, debugged_job} = Support.Factories.Job.create(:started, %{build_id: task.id})

      {:ok, job} = Support.Factories.Job.create(:pending, %{build_id: nil})
      {:ok, _} = Support.Factories.Debug.create_for_job(debugged_job.id, job.id)

      assert RepoProxy.extract_hook_id(job, :debug_job) == {:ok, task.hook_id}
    end

    test "for debug job of a debug job => returns hook_id" do
      {:ok, task} = Support.Factories.Task.create()
      {:ok, debugged_job} = Support.Factories.Job.create(:started, %{build_id: task.id})

      {:ok, debugged_job2} = Support.Factories.Job.create(:pending, %{build_id: nil})
      {:ok, _} = Support.Factories.Debug.create_for_job(debugged_job.id, debugged_job2.id)

      {:ok, job} = Support.Factories.Job.create(:pending, %{build_id: nil})
      {:ok, _} = Support.Factories.Debug.create_for_job(debugged_job2.id, job.id)

      assert RepoProxy.extract_hook_id(job, :debug_job) == {:ok, task.hook_id}
    end
  end

  describe ".find" do
    test "when hook_id is nil => returns nil" do
      assert RepoProxy.find(nil) == {:ok, nil}
    end

    test "when there is a problem with fetching repo_proxy => returns communication_error" do
      hook_id = Factories.Task.hook_id()

      GrpcMock.stub(Support.FakeServers.RepoProxyApi, :describe, fn req, _ ->
        assert req.hook_id == hook_id

        raise "muhahah"
      end)

      assert RepoProxy.find(hook_id) ==
               {:error, :communication_error}
    end

    test "when there is no hook => returns nil" do
      hook_id = Factories.Task.hook_id()
      {:ok, task} = Support.Factories.Task.create()
      {:ok, _} = Support.Factories.Job.create(:pending, %{build_id: task.id})

      GrpcMock.stub(Support.FakeServers.RepoProxyApi, :describe, fn _, _ ->
        status =
          InternalApi.ResponseStatus.new(code: InternalApi.ResponseStatus.Code.value(:BAD_PARAM))

        %InternalApi.RepoProxy.DescribeResponse{status: status, hook: nil}
      end)

      assert RepoProxy.find(hook_id) == {:stop_job_processing, "Hook #{hook_id} not found"}
    end

    test "when everything goes smooth => returns hook" do
      {:ok, task} = Support.Factories.Task.create()
      {:ok, _} = Support.Factories.Job.create(:pending, %{build_id: task.id})

      GrpcMock.stub(Support.FakeServers.RepoProxyApi, :describe, fn _, _ ->
        status = InternalApi.ResponseStatus.new(code: InternalApi.ResponseStatus.Code.value(:OK))

        %InternalApi.RepoProxy.DescribeResponse{status: status, hook: @hook}
      end)

      assert RepoProxy.find(Factories.Task.hook_id()) == {:ok, @hook}
    end
  end
end
