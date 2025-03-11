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
      assert html_response(conn, 200)
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

  describe "status_badge" do
    test "renders badge", %{conn: conn, job: job} do
      conn = get(conn, job_path(conn, :status_badge, job.id))

      assert html_response(conn, 200) ==
               "<div\n  class=\"flex mt1\"\n  data-poll-background\n  data-poll-state=\"poll\"\n  data-poll-href=\"/jobs/job-id/status_badge\"\n>\n<span class='bg-indigo white br1 ph2'>Running</span>\n</div>\n"
    end
  end
end
