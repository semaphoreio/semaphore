defmodule FrontWeb.DashboardControllerTest do
  use FrontWeb.ConnCase
  alias Support.Stubs.DB

  import Mock

  setup %{conn: conn} do
    Cacheman.clear(:front)

    Support.Stubs.init()
    Support.Stubs.build_shared_factories()

    user = Support.Stubs.User.default()
    organization = Support.Stubs.Organization.default()
    dashboard = DB.first(:dashboards)
    workflow = DB.first(:workflows)
    pipeline = DB.first(:pipelines)
    project = DB.first(:projects)

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
      project: project,
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

    test "returns 200 and renders timeout error when workflow fetch fails", %{
      conn: conn,
      project: project
    } do
      with_mocks [
        {Front.RBAC.Members, [:passthrough],
         [list_accessible_projects: fn _org_id, _user_id -> {:ok, [project.id]} end]},
        {Front.Models.Workflow, [:passthrough],
         [list_keyset: fn _params -> {:error, :timeout} end]}
      ] do
        conn =
          conn
          |> get("/")

        assert html_response(conn, 200) =~ "Loading workflows timed out"
      end
    end

    test "returns 200 and renders timeout error when workflow grpc connection fails", %{
      conn: conn,
      project: project
    } do
      with_mocks [
        {Front.RBAC.Members, [:passthrough],
         [list_accessible_projects: fn _org_id, _user_id -> {:ok, [project.id]} end]},
        {Front.Clients.Workflow, [:passthrough],
         [list_keyset: fn _request -> {:error, "Error when opening connection: :timeout"} end]}
      ] do
        conn =
          conn
          |> get("/?dashboard=everyones-activity")

        assert html_response(conn, 200) =~ "Loading workflows timed out"
      end
    end

    test "uses cached workflows when backend times out", %{conn: conn, project: project} do
      with_mocks [
        {Front.RBAC.Members, [:passthrough],
         [list_accessible_projects: fn _org_id, _user_id -> {:ok, [project.id]} end]}
      ] do
        conn =
          conn
          |> get("/")

        assert html_response(conn, 200)
      end

      with_mocks [
        {Front.RBAC.Members, [:passthrough],
         [list_accessible_projects: fn _org_id, _user_id -> {:ok, [project.id]} end]},
        {Front.Models.Workflow, [:passthrough],
         [list_keyset: fn _params -> {:error, :timeout} end]}
      ] do
        conn =
          conn
          |> get("/")

        assert html_response(conn, 200)
        refute html_response(conn, 200) =~ "Loading workflows timed out"
      end
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

    test "returns 200 and renders timeout error when workflow fetch fails", %{
      conn: conn,
      project: project
    } do
      with_mocks [
        {Front.RBAC.Members, [:passthrough],
         [list_accessible_projects: fn _org_id, _user_id -> {:ok, [project.id]} end]},
        {Front.Models.Workflow, [:passthrough],
         [list_keyset: fn _params -> {:error, :timeout} end]}
      ] do
        conn =
          conn
          |> get("/workflows")

        assert html_response(conn, 200) =~ "Loading workflows timed out"
      end
    end
  end

  describe "EE license banner" do
    test "does not show license banner when not EE", %{conn: conn} do
      with_mocks [
        {Front.Clients.License, [],
         [
           verify_license: fn ->
             {:ok,
              %InternalApi.License.VerifyLicenseResponse{
                valid: false,
                expires_at: nil,
                message: "Expired"
              }}
           end
         ]},
        {Front, [], [ee?: fn -> false end]}
      ] do
        conn = get(conn, "/")
        refute html_response(conn, 200) =~ "license-expired-banner"
        refute html_response(conn, 200) =~ "license-expiring-banner"
      end

      with_mocks [
        {Front.Clients.License, [],
         [
           verify_license: fn ->
             expires_at_dt = DateTime.add(DateTime.utc_now(), 3 * 24 * 60 * 60)

             expires_at = %Google.Protobuf.Timestamp{
               seconds: DateTime.to_unix(expires_at_dt),
               nanos: 0
             }

             {:ok,
              %InternalApi.License.VerifyLicenseResponse{
                valid: true,
                expires_at: expires_at,
                message: nil
              }}
           end
         ]},
        {Front, [], [ee?: fn -> false end]}
      ] do
        conn = get(conn, "/")
        refute html_response(conn, 200) =~ "license-expired-banner"
        refute html_response(conn, 200) =~ "license-expiring-banner"
      end
    end

    test "shows expired license banner when license is expired", %{conn: conn} do
      with_mocks [
        {Front.Clients.License, [],
         [
           verify_license: fn ->
             {:ok,
              %InternalApi.License.VerifyLicenseResponse{
                valid: false,
                expires_at: nil,
                message: "Expired"
              }}
           end
         ]},
        {Front, [], [ee?: fn -> true end]}
      ] do
        conn = get(conn, "/")
        assert html_response(conn, 200) =~ "license-expired-banner"

        assert html_response(conn, 200) =~
                 "You are running a Semaphore Enterprise Edition server without a valid license"
      end
    end

    test "shows soon-to-expire license banner when license is expiring soon", %{conn: conn} do
      expires_at_dt = DateTime.add(DateTime.utc_now(), 3 * 24 * 60 * 60)
      expires_at = %Google.Protobuf.Timestamp{seconds: DateTime.to_unix(expires_at_dt), nanos: 0}

      with_mocks [
        {Front.Clients.License, [],
         [
           verify_license: fn ->
             {:ok,
              %InternalApi.License.VerifyLicenseResponse{
                valid: true,
                expires_at: expires_at,
                message: nil
              }}
           end
         ]},
        {Front, [], [ee?: fn -> true end]}
      ] do
        conn = get(conn, "/")
        assert html_response(conn, 200) =~ "license-expiring-banner"

        assert html_response(conn, 200) =~
                 "Your Semaphore Enterprise Edition license will expire on"
      end
    end

    test "does not show license banner for valid license", %{conn: conn} do
      with_mocks [
        {Front.Clients.License, [],
         [
           verify_license: fn ->
             {:ok,
              %InternalApi.License.VerifyLicenseResponse{
                valid: true,
                expires_at: nil,
                message: nil
              }}
           end
         ]},
        {Front, [], [ee?: fn -> true end]}
      ] do
        conn = get(conn, "/")
        refute html_response(conn, 200) =~ "license-expired-banner"
        refute html_response(conn, 200) =~ "license-expiring-banner"
      end
    end
  end
end
