defmodule FrontWeb.DashboardControllerTest do
  use FrontWeb.ConnCase
  alias Support.Stubs.DB

  setup %{conn: conn} do
    Cacheman.clear(:front)

    Support.Stubs.init()
    Support.Stubs.build_shared_factories()

    user = Support.Stubs.User.default()
    organization = Support.Stubs.Organization.default()
    dashboard = DB.first(:dashboards)
    workflow = DB.first(:workflows)
    pipeline = DB.first(:pipelines)

    Support.Stubs.Feature.disable_feature(organization.id, :get_started)

    conn =
      conn
      |> put_req_header("x-semaphore-user-id", user.id)
      |> put_req_header("x-semaphore-org-id", organization.id)

    [
      conn: conn,
      dashboard: dashboard,
      workflow: workflow,
      pipeline: pipeline,
      organization: organization,
      user: user
    ]
  end

  describe "poll" do
    test "returns 200", %{conn: conn, dashboard: dashboard} do
      conn =
        conn
        |> get("/dashboards/#{dashboard.id}/0/poll")

      assert html_response(conn, 200)
    end
  end

  describe "GET index" do
    test "when there is no param that indicate signup => render page without signup", %{
      conn: conn
    } do
      conn =
        conn
        |> get("/")

      assert html_response(conn, 200) =~ "My Work"
      refute html_response(conn, 200) =~ "signup"
    end

    test "when there is param that indicate signup => render page with signup", %{conn: conn} do
      conn =
        conn
        |> get("/?signup=true")

      assert html_response(conn, 200) =~ "My Work"
      assert html_response(conn, 200) =~ "signup"
    end

    test "when the user is not authorized => renders 404", %{conn: conn} do
      Support.Stubs.PermissionPatrol.remove_all_permissions()

      conn =
        conn
        |> get("/")

      assert html_response(conn, 404) =~ "404"
    end

    test "when there are no workflows => returns 200", %{conn: conn} do
      DB.clear(:workflows)

      conn =
        conn
        |> get("/")

      assert html_response(conn, 200) =~ "Pretty quiet"
    end

    test "redirects to get started page if available", %{
      conn: conn,
      organization: organization
    } do
      Support.Stubs.Feature.enable_feature(organization.id, :get_started)

      conn =
        conn
        |> get("/")

      assert html_response(conn, 302) =~ "get_started"
    end
  end

  describe "GET show" do
    test "when the wanted dashboard in not found => renders 404", %{conn: conn} do
      conn =
        conn
        |> get("/dashboards/some-dashboard")

      assert html_response(conn, 404) =~ "404"
    end

    test "when the user is not authorized => renders 404", %{conn: conn, dashboard: dashboard} do
      Support.Stubs.PermissionPatrol.remove_all_permissions()

      conn =
        conn
        |> get("/dashboards/#{dashboard.name}")

      assert html_response(conn, 404) =~ "404"
    end

    test "when the dashboard is found => renders page, but doesn't fetch widgets for the dashboard",
         %{conn: conn, dashboard: dashboard} do
      conn =
        conn
        |> get("/dashboards/#{dashboard.name}")

      assert html_response(conn, 200) =~ dashboard.api_model.metadata.title
      refute html_response(conn, 200) =~ "signup"
      refute html_response(conn, 200) =~ "/workflow/"
    end
  end

  describe "GET workflows" do
    test "returns 200 when there are workflows", %{conn: conn} do
      conn =
        conn
        |> get("/workflows")

      assert html_response(conn, 200)
    end

    test "returns 200 when there are no workflows", %{conn: conn} do
      DB.clear(:workflows)

      conn =
        conn
        |> get("/workflows")

      assert html_response(conn, 200)
    end
  end
end
