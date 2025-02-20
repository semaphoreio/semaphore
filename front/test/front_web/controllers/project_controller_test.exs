defmodule FrontWeb.ProjectControllerTest do
  use FrontWeb.ConnCase

  alias Support.Stubs.DB

  setup %{conn: conn} do
    Cacheman.clear(:front)

    Support.Stubs.init()
    Support.Stubs.build_shared_factories()
    Support.Stubs.PermissionPatrol.remove_all_permissions()

    user = DB.first(:users)
    organization = DB.first(:organizations)
    project = DB.first(:projects)
    branch = DB.first(:branches)

    conn =
      conn
      |> put_req_header("x-semaphore-user-id", user.id)
      |> put_req_header("x-semaphore-org-id", organization.id)

    [
      conn: conn,
      organization: organization,
      user: user,
      project: project,
      branch: branch
    ]
  end

  describe "GET index" do
    test "when the user is not authorized to view the org, it renders 404", %{conn: conn} do
      conn =
        conn
        |> get(project_path(build_conn(), :index))

      assert html_response(conn, 404) =~ "404"
    end

    test "when listing projects succeeds, it returns 200, lists projects and sets necessary assigns",
         %{conn: conn, organization: organization, user: user, project: project} do
      Support.Stubs.PermissionPatrol.add_permissions(
        organization.id,
        user.id,
        "organization.view"
      )

      GrpcMock.stub(
        RBACMock,
        :list_accessible_projects,
        InternalApi.RBAC.ListAccessibleProjectsResponse.new(project_ids: [project.id])
      )

      conn =
        conn
        |> get(project_path(build_conn(), :index))

      assert conn.assigns.title == organization.api_model.name
      assert Enum.any?(conn.assigns.categorized_projects)

      assert html_response(conn, 200) =~ "All projects in this organization"
    end
  end

  describe "GET edit_workflow" do
    test "when project doesn't have branches, it redirects to the onboarding template page",
         %{conn: conn, project: project, organization: organization, user: user} do
      DB.clear(:workflows)
      Support.Stubs.PermissionPatrol.allow_everything(organization.id, user.id)

      conn =
        conn
        |> get("/projects/#{project.name}/edit_workflow")

      assert html_response(conn, 200) =~ "workflow-editor-tabs"
    end
  end

  describe "GET show" do
    test "when the user can't authorize private project => returns 404", %{
      conn: conn,
      user: _user,
      organization: _organization,
      project: project
    } do
      conn =
        conn
        |> get("/projects/#{project.name}")

      assert html_response(conn, 404) =~ "404"
    end

    test "when the user can't authorize public project => returns 200", %{
      conn: conn,
      user: _user,
      organization: _organization,
      project: project
    } do
      Support.Stubs.Project.switch_project_visibility(project, "public")

      conn =
        conn
        |> get("/projects/#{project.name}")

      assert conn.assigns.authorization == :guest
      assert conn.assigns.anonymous == false
      refute conn.assigns[:layout_model]

      assert html_response(conn, 200) =~ "Blazing-fast build and deploy!"
      assert html_response(conn, 200) =~ project.name
    end

    test "when the project doesn't exist => returns 404", %{
      conn: conn,
      organization: organization,
      user: user
    } do
      Support.Stubs.PermissionPatrol.allow_everything(organization.id, user.id)

      conn =
        conn
        |> get("/projects/foo_bar")

      assert html_response(conn, 404) =~ "404"
    end

    test "when there are no workflows => returns 200", %{
      conn: conn,
      organization: organization,
      user: user,
      project: project
    } do
      Support.Stubs.PermissionPatrol.add_permissions(
        organization.id,
        user.id,
        project.id,
        "project.view"
      )

      DB.clear(:workflows)

      conn =
        conn
        |> get("/projects/#{project.name}?force_cold_boot=true")

      assert html_response(conn, 200) =~ "Anything to add"
    end
  end

  describe "GET filtered_branches" do
    test "when everything is ok => renders the template", %{
      conn: conn,
      organization: organization,
      user: user,
      project: project,
      branch: branch
    } do
      Support.Stubs.PermissionPatrol.add_permissions(
        organization.id,
        user.id,
        project.id,
        "project.view"
      )

      conn =
        conn
        |> get("/projects/#{project.name}/filtered_branches?name_contains=master")

      assert json_response(conn, 200) == [
               %{
                 "id" => branch.id,
                 "type" => "branch",
                 "display_name" => branch.api_model.name,
                 "html_url" => "/branches/#{branch.id}"
               }
             ]
    end
  end

  describe "GET workflows" do
    setup %{project: project, organization: organization, user: user} = ctx do
      Support.Stubs.PermissionPatrol.add_permissions(
        organization.id,
        user.id,
        project.id,
        "project.view"
      )

      ctx
    end

    test "when user is not authenticated, but has 'requester' param, ignore it", %{
      conn: conn,
      project: project
    } do
      Support.Stubs.Project.switch_project_visibility(project, "public")

      conn =
        conn
        |> put_req_header("x-semaphore-user-anonymous", "true")
        |> delete_req_header("x-semaphore-user-id")
        |> get("/projects/#{project.name}/workflows?requester=true")

      assert html_response(conn, 200)
    end

    test "returns 200 when there are workflows", %{conn: conn, project: project} do
      conn =
        conn
        |> get("/projects/#{project.name}/workflows")

      assert html_response(conn, 200)
    end

    test "returns 200 when there are no workflows", %{conn: conn, project: project} do
      DB.clear(:workflows)

      conn =
        conn
        |> get("/projects/#{project.name}/workflows")

      assert html_response(conn, 200)
    end
  end
end
