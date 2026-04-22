defmodule JobPageWeb.JobControllerTest do
  use FrontWeb.ConnCase
  alias Support.Stubs.DB
  import Mock

  setup do
    Support.Stubs.init()
    Support.Stubs.build_shared_factories()

    :ok
  end

  def ids do
    org_id =
      DB.first(:organizations)
      |> Map.get(:id)

    user_id =
      DB.first(:users)
      |> Map.get(:id)

    job_id =
      DB.first(:jobs)
      |> Map.get(:id)

    workflow_id =
      DB.first(:workflows)
      |> Map.get(:id)

    %{user: user_id, org: org_id, job: job_id, workflow: workflow_id}
  end

  def auth_get(conn, url) do
    conn
    |> Plug.Conn.put_req_header("x-semaphore-user-id", ids().user)
    |> Plug.Conn.put_req_header("x-semaphore-anonymous", "false")
    |> Plug.Conn.put_req_header("x-semaphore-org-id", ids().org)
    |> get(url)
  end

  describe "when the user is not authorized to see the job" do
    setup do
      Support.Stubs.PermissionPatrol.remove_all_permissions()

      :ok
    end

    test "GET /jobs/<id>", %{conn: conn} do
      conn = auth_get(conn, "/jobs/#{ids().job}")

      assert html_response(conn, 404) =~ "Not Found"
    end
  end

  describe "when the user is authenticated" do
    setup ctx do
      Support.Stubs.PermissionPatrol.allow_everything(ids().org, ids().user)
      ctx
    end

    test "GET /jobs/<id>", %{conn: conn} do
      with_mocks([
        {Front.Models.Project, [:passthrough], []}
      ]) do
        conn = auth_get(conn, "/jobs/#{ids().job}")

        assert html_response(conn, 200) =~ "Job log"
      end
    end

    test "artifacts button attributes are assigned", %{conn: conn} do
      with_mocks([
        {Front.Models.Project, [:passthrough], []}
      ]) do
        conn = auth_get(conn, "/jobs/#{ids().job}")

        assert conn.assigns.organization_id != nil
        assert conn.assigns.job.id != nil
        assert conn.assigns.job.project_id != nil
      end
    end

    test "artifacts logs URL is assigned", %{conn: conn} do
      with_mocks([
        {Front.Models.Project, [:passthrough], []}
      ]) do
        conn = auth_get(conn, "/jobs/#{ids().job}")
        assert conn.assigns.artifact_logs_url != nil
        assert conn.assigns.artifact_logs_compressed == false
      end
    end

    test "compressed artifacts logs are assigned", %{conn: conn} do
      with_mocks([
        {Front.Models.Project, [:passthrough], []}
      ]) do
        job = DB.find(:jobs, ids().job)

        Support.Stubs.Task.add_job_artifact(job,
          path: "agent/job_logs.txt.gz",
          url: "http://example.com/agent/job_logs.txt.gz"
        )

        conn = auth_get(conn, "/jobs/#{ids().job}")

        assert conn.assigns.artifact_logs_url != nil
        assert conn.assigns.artifact_logs_compressed == true
      end
    end
  end

  test "when the user can't authorize public project => returns 200" do
    Support.FakeServices.stub_responses()

    with_mocks([
      {Front.Models.Workflow, [:passthrough],
       [
         preload_requester: fn wf -> wf end,
         preload_commit_data: fn wf -> wf end,
         preload_pipelines: fn wf -> wf end,
         preload_summary: fn wf -> wf end,
         find: fn _id, _ -> Front.Models.Workflow.find(ids().workflow) end
       ]}
    ]) do
      public_project =
        InternalApi.Projecthub.DescribeResponse.new(
          metadata: Support.Factories.response_meta(),
          project: Support.Factories.projecthub_api_described_project([], true)
        )

      GrpcMock.stub(ProjecthubMock, :describe, public_project)

      conn =
        build_conn()
        |> put_req_header("x-semaphore-user-id", "78114608-be8a-465a-b9cd-81970fb802c0")
        |> put_req_header("x-semaphore-org-id", "78114608-be8a-465a-b9cd-81970fb802c5")
        |> get("/jobs/#{ids().job}")

      assert conn.assigns.authorization == :guest
      assert conn.assigns.anonymous == false
      assert html_response(conn, 200) =~ "Blazing-fast build and deploy!"
      assert html_response(conn, 200) =~ public_project.project.metadata.name
    end
  end

  describe "GET /job/<id>/plain_logs.json" do
    setup do
      Support.Stubs.PermissionPatrol.allow_everything()

      :ok
    end

    @tag :skip
    test "when the user can access the logs => it returns the logs in JSON format", %{conn: conn} do
      _response =
        conn
        |> auth_get("/jobs/#{ids().job}/plain_logs.json")
        |> text_response(200)

      assert _response = "cat /tmp/a.txt"
    end
  end
end
