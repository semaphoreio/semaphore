defmodule FrontWeb.JobControllerTest do
  use FrontWeb.ConnCase

  alias Support.Stubs.DB
  alias InternalApi.ServerFarm.Job.DescribeResponse
  alias InternalApi.ServerFarm.Job.Job

  setup %{conn: conn} do
    Support.Stubs.init()
    Support.Stubs.build_shared_factories()

    user = DB.first(:users)
    organization = DB.first(:organizations)

    Support.Stubs.PermissionPatrol.allow_everything(organization.id, user.id)

    conn =
      conn
      |> put_req_header("x-semaphore-user-id", user.id)
      |> put_req_header("x-semaphore-org-id", organization.id)

    task = DB.first(:tasks)
    job = Support.Stubs.Task.create_job(task, id: "job-id")
    debug_job = Support.Stubs.Task.create_job(task, id: "debug-job-id")

    GrpcMock.stub(InternalJobMock, :describe, fn req, _ ->
      job = DB.find(:jobs, req.job_id)
      task = DB.find(:tasks, job.task_id)
      task_job = job |> DB.extract(:api_model)

      DescribeResponse.new(
        status: InternalApi.ResponseStatus.new(code: InternalApi.ResponseStatus.Code.value(:OK)),
        job:
          Job.new(
            id: task_job.id,
            project_id: task.project_id,
            branch_id: task.branch_id,
            hook_id: task.api_model.hook_id,
            ppl_id: task.api_model.ppl_id,
            timeline: Job.Timeline.new(),
            state: Job.State.value(:STARTED),
            machine_type: "e1-standard-2",
            self_hosted: false,
            name: task_job.name,
            index: task_job.index,
            is_debug_job: task_job.id == debug_job.id
          )
      )
    end)

    {:ok,
     %{
       conn: conn,
       job: job,
       debug_job: debug_job,
       task: task
     }}
  end

  describe "show" do
    test "displays job details", %{conn: conn, job: job} do
      conn = get(conn, job_path(conn, :show, job.id))
      html = html_response(conn, 200)
      refute html =~ "Reused job"
    end

    test "redirects when accessing debug job", %{conn: conn, debug_job: debug_job, task: task} do
      conn = get(conn, job_path(conn, :show, debug_job.id))
      assert redirected_to(conn) == project_path(conn, :show, task.project_id)
      assert get_flash(conn, :alert) == "Debug job cannot be accessed."
    end

    test "returns 404 when job doesn't exist", %{conn: conn} do
      conn = get(conn, job_path(conn, :show, "non-existent-job"))
      assert html_response(conn, 404) =~ "404"
    end
  end

  describe "show for a reused job" do
    test "renders the reused-job banner linking to the original", %{conn: conn, job: job} do
      original_job_id = UUID.uuid4()

      GrpcMock.stub(InternalJobMock, :describe, fn req, _ ->
        job = DB.find(:jobs, req.job_id)
        task = DB.find(:tasks, job.task_id)
        task_job = job |> DB.extract(:api_model)

        DescribeResponse.new(
          status:
            InternalApi.ResponseStatus.new(code: InternalApi.ResponseStatus.Code.value(:OK)),
          job:
            Job.new(
              id: task_job.id,
              project_id: task.project_id,
              branch_id: task.branch_id,
              hook_id: task.api_model.hook_id,
              ppl_id: task.api_model.ppl_id,
              timeline: Job.Timeline.new(),
              state: Job.State.value(:FINISHED),
              result: Job.Result.value(:PASSED),
              machine_type: "e1-standard-2",
              self_hosted: false,
              name: task_job.name,
              index: task_job.index,
              original_job_id: original_job_id
            )
        )
      end)

      conn = get(conn, job_path(conn, :show, job.id))
      html = html_response(conn, 200)

      assert html =~ "Reused job"
      assert html =~ "/jobs/#{original_job_id}"
    end

    test "fetches plain logs from the original job", %{conn: conn, job: job} do
      original_job_id = "9e0a1b2c-3d4e-4f5a-8b6c-7d8e9f0a1b2c"

      GrpcMock.stub(InternalJobMock, :describe, fn req, _ ->
        job = DB.find(:jobs, req.job_id)
        task = DB.find(:tasks, job.task_id)
        task_job = job |> DB.extract(:api_model)
        ts = Google.Protobuf.Timestamp.new(seconds: 1_739_285_890)

        DescribeResponse.new(
          status:
            InternalApi.ResponseStatus.new(code: InternalApi.ResponseStatus.Code.value(:OK)),
          job:
            Job.new(
              id: task_job.id,
              project_id: task.project_id,
              branch_id: task.branch_id,
              hook_id: task.api_model.hook_id,
              ppl_id: task.api_model.ppl_id,
              timeline: Job.Timeline.new(created_at: ts, started_at: ts, finished_at: ts),
              state: Job.State.value(:FINISHED),
              result: Job.Result.value(:PASSED),
              machine_type: "e1-standard-2",
              self_hosted: false,
              name: task_job.name,
              index: task_job.index,
              original_job_id: original_job_id
            )
        )
      end)

      conn = get(conn, job_path(conn, :plain_logs, job.id))

      assert text_response(conn, 200) =~ "log-of-the-original-job"
    end
  end

  describe "status_badge" do
    test "renders badge", %{conn: conn, job: job} do
      conn = get(conn, job_path(conn, :status_badge, job.id))

      assert html_response(conn, 200) ==
               "<div\n  class=\"flex mt1\"\n  data-poll-background\n  data-poll-state=\"poll\"\n  data-poll-href=\"/jobs/job-id/status_badge\"\n>\n  <span class=\"bg-indigo white br1 ph2\">\nRunning\n  </span>\n</div>\n"
    end
  end

  # Regression tests: the job page header used to always show
  # @workflow.created_at, which is pinned to the workflow's FIRST pipeline
  # (initial_request == true) and never changes on rebuild. It must show the
  # created_at of the pipeline the job actually belongs to.
  describe "show header timestamp" do
    setup do
      user = Support.Stubs.User.create_default()
      org = Support.Stubs.Organization.create_default(owner_id: user.id)
      Support.Stubs.PermissionPatrol.allow_everything(org.id, user.id)

      project =
        Support.Stubs.Project.create(org, user,
          run_on: ["branches"],
          state: InternalApi.Projecthub.Project.Status.State.value(:READY)
        )

      branch = Support.Stubs.Branch.create(project)
      hook = Support.Stubs.Hook.create(branch)

      {:ok, user: user, org: org, hook: hook}
    end

    defp with_org_headers(conn, org, user) do
      conn
      |> put_req_header("x-semaphore-user-id", user.id)
      |> put_req_header("x-semaphore-org-id", org.id)
    end

    defp job_in_pipeline(pipeline) do
      task = Support.Stubs.Task.create_empty_task("req-token", pipeline)
      Support.Stubs.Task.create_job(task, name: "Job")
    end

    defp formatted(unix_seconds) do
      unix_seconds |> DateTime.from_unix!() |> Timex.format!("%FT%T%:z", :strftime)
    end

    test "non-rebuilt job: header time equals the pipeline's own created_at",
         %{conn: conn, user: user, org: org, hook: hook} do
      workflow_created_at = 1_700_000_000
      pipeline_created_at = 1_700_000_500

      workflow = Support.Stubs.Workflow.create(hook, user, created_at: workflow_created_at)

      pipeline =
        Support.Stubs.Pipeline.create_initial(workflow,
          created_at: Google.Protobuf.Timestamp.new(seconds: pipeline_created_at)
        )

      job = job_in_pipeline(pipeline)
      conn = with_org_headers(conn, org, user)

      html = conn |> get(job_path(conn, :show, job.id)) |> html_response(200)

      assert html =~ formatted(pipeline_created_at)
      refute html =~ formatted(workflow_created_at)
    end

    test "rebuilt job: header shows the rebuild pipeline's created_at, not the workflow's first-pipeline time",
         %{conn: conn, user: user, org: org, hook: hook} do
      workflow_created_at = 1_700_000_000
      rebuild_created_at = 1_700_999_999

      workflow = Support.Stubs.Workflow.create(hook, user, created_at: workflow_created_at)

      # The workflow's first (initial_request) pipeline - this is what
      # @workflow.created_at is pinned to.
      Support.Stubs.Pipeline.create_initial(workflow,
        created_at: Google.Protobuf.Timestamp.new(seconds: workflow_created_at)
      )

      # A later partial rebuild: same workflow, new (non-initial) pipeline id.
      rebuild_pipeline =
        Support.Stubs.Pipeline.create(workflow,
          created_at: Google.Protobuf.Timestamp.new(seconds: rebuild_created_at)
        )

      job = job_in_pipeline(rebuild_pipeline)
      conn = with_org_headers(conn, org, user)

      html = conn |> get(job_path(conn, :show, job.id)) |> html_response(200)

      assert html =~ formatted(rebuild_created_at)
      refute html =~ formatted(workflow_created_at)
    end
  end
end
