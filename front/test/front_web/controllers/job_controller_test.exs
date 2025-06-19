defmodule FrontWeb.JobControllerTest do
  use FrontWeb.ConnCase

  alias Support.Stubs
  alias Support.Stubs.DB
  alias InternalApi.ServerFarm.Job.DescribeResponse
  alias InternalApi.ServerFarm.Job.Job
  alias InternalApi.User.User, as: UserProto

  setup %{conn: conn} do
    Cacheman.clear(:front)

    Stubs.init()
    Stubs.build_shared_factories()

    user = Stubs.User.create_default()
    organization = Stubs.Organization.create_default()

    conn =
      conn
      |> put_req_header("x-semaphore-user-id", user.id)
      |> put_req_header("x-semaphore-org-id", organization.id)

    task = DB.first(:tasks)
    job = Stubs.Task.create_job(task, id: "job-id")
    debug_job = Stubs.Task.create_job(task, id: "debug-job-id")

    # Create a stopped job with stopped_by field set
    stopped_job =
      Stubs.Task.create_job(task,
        id: "stopped-job-id"
      )

    # Create a job stopped by system
    system_stopped_job =
      Stubs.Task.create_job(task,
        id: "system-stopped-job-id"
      )

    GrpcMock.stub(InternalJobMock, :describe, fn req, _ ->
      job = DB.find(:jobs, req.job_id)
      task = DB.find(:tasks, job.task_id)
      task_job = job |> DB.extract(:api_model)

      stopped_by =
        case task_job.id do
          "stopped-job-id" -> user.id
          "system-stopped-job-id" -> "system:timeout"
          _ -> ""
        end

      returned_job =
        Job.new(
          id: task_job.id,
          project_id: task.project_id,
          branch_id: task.branch_id,
          hook_id: task.api_model.hook_id,
          ppl_id: task.api_model.ppl_id,
          timeline: Job.Timeline.new(),
          state: Job.State.value(:FINISHED),
          machine_type: "e1-standard-2",
          self_hosted: false,
          name: task_job.name,
          index: task_job.index,
          is_debug_job: task_job.id == debug_job.id,
          stopped_by: stopped_by
        )

      DescribeResponse.new(
        status: InternalApi.ResponseStatus.new(code: InternalApi.ResponseStatus.Code.value(:OK)),
        job: returned_job
      )
    end)

    GrpcMock.stub(UserMock, :describe, fn req, _ ->
      user = DB.find(:users, req.user_id)

      InternalApi.User.DescribeResponse.new(
        status: InternalApi.ResponseStatus.new(code: InternalApi.ResponseStatus.Code.value(:OK)),
        user_id: user.id,
        name: user.api_model.name,
        avatar_url: user.api_model.avatar_url,
        email: user.api_model.email,
        company: user.api_model.company,
        created_at: Google.Protobuf.Timestamp.new(seconds: 1_622_548_800),
        user: UserProto.new(single_org_user: false, org_id: ""),
        repository_providers: []
      )
    end)

    {:ok,
     %{
       conn: conn,
       job: job,
       debug_job: debug_job,
       task: task,
       stopped_job: stopped_job,
       system_stopped_job: system_stopped_job,
       user: user
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

    test "displays stopped job with user who stopped it", %{
      conn: conn,
      stopped_job: stopped_job,
      user: user
    } do
      conn = get(conn, job_path(conn, :show, stopped_job.id))
      response = html_response(conn, 200)

      assert response =~ "Job was stopped by #{user.name}"
    end

    test "displays job stopped by system", %{conn: conn, system_stopped_job: system_stopped_job} do
      conn = get(conn, job_path(conn, :show, system_stopped_job.id))
      response = html_response(conn, 200)

      assert response =~ "Job was stopped by the system"
    end
  end
end
