defmodule FrontWeb.ArtifactsControllerTest do
  use FrontWeb.ConnCase

  alias Support.Stubs.{DB, PermissionPatrol}

  @empty_list_response InternalApi.Artifacthub.ListPathResponse.new(items: [])

  setup %{conn: conn} do
    Cacheman.clear(:front)
    FunRegistry.clear!()
    Support.FakeServices.stub_responses()

    Support.Stubs.init()
    Support.Stubs.build_shared_factories()

    project = DB.first(:projects)
    workflow = DB.first(:workflows)
    organization = DB.first(:organizations)
    job = DB.first(:jobs)
    user = DB.first(:users)

    PermissionPatrol.allow_everything(organization.id, user.id)

    conn =
      conn
      |> Plug.Conn.put_req_header("x-semaphore-user-id", user.id)
      |> Plug.Conn.put_req_header("x-semaphore-org-id", organization.id)

    [
      conn: conn,
      project: project,
      job: job,
      workflow: workflow,
      organization: organization,
      user: user
    ]
  end

  describe "GET index" do
    test "when the user is not authorized to view the org, it renders 404", %{
      conn: conn,
      project: project
    } do
      PermissionPatrol.remove_all_permissions()

      conn =
        conn
        |> get(artifacts_path(conn, :projects, project.name, path: "some-path"))

      assert html_response(conn, 404) =~ "404"
    end

    test "when listing non-existing artifact resource for project, it shows 404 page", %{
      conn: conn,
      project: project
    } do
      GrpcMock.stub(ArtifacthubMock, :list_path, fn _req, _stream -> @empty_list_response end)

      conn =
        conn
        |> get(artifacts_path(conn, :projects, project.name, path: "non-existing-path"))

      assert html_response(conn, 404)
    end

    test "when listing non-existing artifact resource for workflow, it shows 404 page", %{
      conn: conn,
      workflow: workflow
    } do
      GrpcMock.stub(ArtifacthubMock, :list_path, fn _req, _stream -> @empty_list_response end)

      conn =
        conn
        |> get(artifacts_path(conn, :workflows, workflow.id, path: "non-existing-path"))

      assert html_response(conn, 404)
    end

    test "when listing non-existing artifact resource for job, it shows 404 page", %{
      conn: conn,
      job: job
    } do
      GrpcMock.stub(ArtifacthubMock, :list_path, fn _req, _stream -> @empty_list_response end)

      conn =
        conn
        |> get(artifacts_path(conn, :jobs, job.id, path: "non-existing-path"))

      assert html_response(conn, 404)
    end

    test "projects: when artifacthub request succeeds and returns files, it returns 200, lists resources",
         %{conn: conn, project: project, organization: organization} do
      conn =
        conn
        |> get(artifacts_path(conn, :projects, project.name, path: "dir/subdir"))

      assert html_response(conn, 200) =~ "Artifacts"
      refute html_response(conn, 200) =~ "Noting stored in Artifacts"
      assert html_response(conn, 200) =~ "Project Artifacts・#{project.name}・#{organization.name}"
      assert html_response(conn, 200) =~ "README.md"
      assert html_response(conn, 200) =~ "dir"
      assert html_response(conn, 200) =~ "subdir"
    end

    test "workflows: when artifacthub request succeeds and returns files, it returns 200, lists resources and sets neccessary assigns",
         %{conn: conn, project: project, workflow: workflow, organization: organization} do
      conn =
        conn
        |> get(artifacts_path(conn, :workflows, workflow.id, path: "dir/subdir"))

      assert html_response(conn, 200) =~ "Artifacts"
      refute html_response(conn, 200) =~ "Noting stored in Artifacts"
      assert html_response(conn, 200) =~ "Workflow Artifacts・#{project.name}・#{organization.name}"
      assert html_response(conn, 200) =~ "README.md"
      assert html_response(conn, 200) =~ "dir"
      assert html_response(conn, 200) =~ "subdir"
    end

    test "jobs: when artifacthub request succeeds and returns files, it returns 200, lists resources and sets neccessary assigns",
         %{conn: conn, project: project, job: job, organization: organization} do
      conn =
        conn
        |> get(artifacts_path(conn, :jobs, job.id, path: "dir/subdir"))

      assert html_response(conn, 200) =~ "Artifacts"
      refute html_response(conn, 200) =~ "Noting stored in Artifacts"
      assert html_response(conn, 200) =~ "Job Artifacts・#{project.name}・#{organization.name}"
      assert html_response(conn, 200) =~ "README.md"
      assert html_response(conn, 200) =~ "dir"
      assert html_response(conn, 200) =~ "subdir"
    end

    test "when request succeeds and there are no listed resources, it returns 200 and zero artifacts page",
         %{conn: conn, project: project, workflow: workflow, job: job} do
      GrpcMock.stub(ArtifacthubMock, :list_path, fn _req, _stream -> @empty_list_response end)

      conn =
        conn
        |> get(artifacts_path(conn, :projects, project.name))

      assert html_response(conn, 200) =~ "Nothing stored in Artifacts"
      refute html_response(conn, 200) =~ "Files"

      conn =
        conn
        |> get(artifacts_path(conn, :workflows, workflow.id))

      assert html_response(conn, 200) =~ "Nothing stored in Artifacts"
      refute html_response(conn, 200) =~ "Files"

      conn =
        conn
        |> get(artifacts_path(conn, :jobs, job.id))

      assert html_response(conn, 200) =~ "Nothing stored in Artifacts"
      refute html_response(conn, 200) =~ "Files"
    end

    test "when artifacthub request fails, it raises 500", %{
      conn: conn,
      project: project,
      workflow: workflow,
      job: job
    } do
      GrpcMock.stub(ArtifacthubMock, :list_path, fn _, _ ->
        raise GRPC.RPCError, status: 2, message: "Unknown"
      end)

      assert_raise(
        CaseClauseError,
        "no case clause matching: {:error, :grpc_req_failed}",
        fn -> conn |> get(artifacts_path(conn, :projects, project.name)) end
      )

      assert_raise(
        CaseClauseError,
        "no case clause matching: {:error, :grpc_req_failed}",
        fn -> conn |> get(artifacts_path(conn, :workflows, workflow.id)) end
      )

      assert_raise(
        CaseClauseError,
        "no case clause matching: {:error, :grpc_req_failed}",
        fn -> conn |> get(artifacts_path(conn, :jobs, job.id)) end
      )
    end
  end

  describe "DELETE destroy" do
    test "when the user is not authorized to delete an artifact, it renders 404", %{
      conn: conn,
      project: project,
      organization: organization,
      user: user
    } do
      PermissionPatrol.remove_all_permissions()

      PermissionPatrol.allow_everything_except(
        organization.id,
        user.id,
        "project.artifacts.delete"
      )

      conn =
        conn
        |> delete(artifacts_path(conn, :projects_destroy, project.name, "test"))

      assert html_response(conn, 404) =~ "404"
    end

    test "when deleting an artifact succeeds for project, it redirects to artifacts page", %{
      conn: conn,
      project: project
    } do
      conn =
        conn
        |> delete(artifacts_path(conn, :projects_destroy, project.name, "dir/subdir"))

      assert redirected_to(conn) == artifacts_path(conn, :projects, project.name)
      assert get_flash(conn, :notice) == "Artifact resource deleted."
    end

    test "when deleting an artifact succeeds for workflow, it redirects to artifacts page", %{
      conn: conn,
      workflow: workflow
    } do
      conn =
        conn
        |> delete(artifacts_path(conn, :workflows_destroy, workflow.id, "dir/subdir"))

      assert redirected_to(conn) == artifacts_path(conn, :workflows, workflow.id)
      assert get_flash(conn, :notice) == "Artifact resource deleted."
    end

    test "when deleting an artifact succeeds for job, it redirects to artifacts page", %{
      conn: conn,
      job: job
    } do
      conn =
        conn
        |> delete(artifacts_path(conn, :jobs_destroy, job.id, "dir/subdir"))

      assert redirected_to(conn) == artifacts_path(conn, :jobs, job.id)
      assert get_flash(conn, :notice) == "Artifact resource deleted."
    end

    test "when artifacthub request fails for project, redirects to artifacts page", %{
      conn: conn,
      project: project
    } do
      GrpcMock.stub(ArtifacthubMock, :delete_path, fn _, _ ->
        raise GRPC.RPCError, status: 2, message: "Unknown"
      end)

      conn =
        conn
        |> delete(artifacts_path(conn, :projects_destroy, project.name, "dir/subdir"))

      assert redirected_to(conn) == artifacts_path(conn, :projects, project.name)
      assert get_flash(conn, :alert) == "Failed to delete the artifact."
    end

    test "when artifacthub request fails for workflows, redirects to artifacts page", %{
      conn: conn,
      workflow: workflow
    } do
      GrpcMock.stub(ArtifacthubMock, :delete_path, fn _, _ ->
        raise GRPC.RPCError, status: 2, message: "Unknown"
      end)

      conn =
        conn
        |> delete(artifacts_path(conn, :workflows_destroy, workflow.id, "dir/subdir"))

      assert redirected_to(conn) == artifacts_path(conn, :workflows, workflow.id)
      assert get_flash(conn, :alert) == "Failed to delete the artifact."
    end

    test "when artifacthub request fails for job, redirects to artifacts page", %{
      conn: conn,
      job: job
    } do
      GrpcMock.stub(ArtifacthubMock, :delete_path, fn _, _ ->
        raise GRPC.RPCError, status: 2, message: "Unknown"
      end)

      conn =
        conn
        |> delete(artifacts_path(conn, :jobs_destroy, job.id, "dir/subdir"))

      assert redirected_to(conn) == artifacts_path(conn, :jobs, job.id)
      assert get_flash(conn, :alert) == "Failed to delete the artifact."
    end
  end

  describe "GET download" do
    test "when the user is not authorized to fetch an artifact, it renders 404", %{
      conn: conn,
      project: project,
      organization: organization,
      user: user
    } do
      PermissionPatrol.remove_all_permissions()
      PermissionPatrol.allow_everything_except(organization.id, user.id, "project.artifacts.view")

      conn =
        conn
        |> get(artifacts_path(conn, :projects_download, project.name, "test", path: "tmp"))

      assert html_response(conn, 404) =~ "404"
    end

    test "when request is successfull, it redirects to artifact URL", %{conn: conn, job: job} do
      conn =
        conn
        |> get(artifacts_path(conn, :jobs_download, job.id, "dir/subdir/README.md", path: "tmp"))

      assert redirected_to(conn) == "http://some/path/dir/subdir/README.md"

      assert conn.assigns.resource_path == "dir/subdir/README.md"
      assert conn.assigns.page_path == "tmp"
    end

    test "when artifacthub request fails, redirects to list source page", %{
      conn: conn,
      project: project,
      workflow: workflow,
      job: job
    } do
      GrpcMock.stub(ArtifacthubMock, :get_signed_url, fn _, _ ->
        raise GRPC.RPCError, status: 2, message: "Unknown"
      end)

      conn =
        conn
        |> get(artifacts_path(conn, :projects_download, project.name, "tmp", path: "tmp"))

      assert get_flash(conn, :alert) == "Failed to fetch requested artifact."

      conn =
        conn
        |> get(artifacts_path(conn, :workflows_download, workflow.id, "tmp", path: "tmp"))

      assert get_flash(conn, :alert) == "Failed to fetch requested artifact."

      conn =
        conn
        |> get(artifacts_path(conn, :jobs_download, job.id, "tmp", path: "tmp"))

      assert get_flash(conn, :alert) == "Failed to fetch requested artifact."
    end
  end
end
