defmodule FrontWeb.Plugs.PutProjectAssignsTest do
  use FrontWeb.ConnCase

  import Mock
  alias FrontWeb.Plugs.PutProjectAssigns
  alias Support.Stubs.DB

  setup %{conn: conn} do
    org = Support.Stubs.Organization.create_default()
    user = Support.Stubs.User.create_default()
    project = Support.Stubs.Project.create(org, user, name: "test_project")

    conn =
      conn
      |> Plug.Conn.assign(:organization_id, org.id)

    %{conn: conn, project: project}
  end

  describe "call with invalid data" do
    test "when there is no data present in the assigns", %{conn: conn} do
      conn = conn |> PutProjectAssigns.call([])

      assert html_response(conn, 404)
    end
  end

  describe "call with project id" do
    test "when project does not exist", %{conn: conn} do
      conn =
        conn |> Map.merge(%{params: %{"name_or_id" => "random"}}) |> PutProjectAssigns.call([])

      assert html_response(conn, 404)
    end

    test "when project by name exists", %{conn: conn, project: project} do
      conn =
        conn
        |> Map.merge(%{params: %{"name_or_id" => project.name}})
        |> PutProjectAssigns.call([])

      assert conn.assigns.project.id == project.id
    end

    test "when project by id exists", %{conn: conn, project: project} do
      conn =
        conn |> Map.merge(%{params: %{"name_or_id" => project.id}}) |> PutProjectAssigns.call([])

      assert conn.assigns.project.id == project.id
    end
  end

  describe "call with workflow id" do
    test "when workflow does not exist", %{conn: conn} do
      conn =
        conn |> Map.merge(%{params: %{"workflow_id" => "random"}}) |> PutProjectAssigns.call([])

      assert html_response(conn, 404)
    end

    test "when workflow exists", %{conn: conn} do
      Support.Stubs.init()
      Support.Stubs.build_shared_factories()
      wf = DB.first(:workflows)
      conn = conn |> Map.merge(%{params: %{"workflow_id" => wf.id}}) |> PutProjectAssigns.call([])

      assert conn.assigns.project.id == wf.api_model.project_id
      assert conn.assigns.workflow.id == wf.id
    end
  end

  describe "call with job id" do
    test "when the job does not exist", %{conn: conn} do
      conn = conn |> Map.merge(%{params: %{"id" => "random"}}) |> PutProjectAssigns.call([])

      assert html_response(conn, 404)
    end

    test "when the job exists", %{conn: conn, project: project} do
      job_id = Ecto.UUID.generate()
      project_id = project.id

      with_mock Front.Models.Job, find: fn _ -> %{id: job_id, project_id: project_id} end do
        conn = conn |> Map.merge(%{params: %{"id" => job_id}}) |> PutProjectAssigns.call([])

        assert conn.assigns.project.id == project_id
        assert conn.assigns.job.id == job_id
      end
    end
  end
end
