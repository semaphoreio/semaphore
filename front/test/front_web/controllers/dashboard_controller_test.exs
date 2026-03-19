defmodule FrontWeb.DashboardControllerTest do
  use FrontWeb.ConnCase
  alias Front.DashboardPage.Model
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

    test "uses a new cache key when accessible project set changes", %{
      conn: conn,
      organization: organization,
      user: user,
      project: project
    } do
      project_b = Support.Stubs.Project.create(organization, user, name: "project-b-rbac")
      branch_b = Support.Stubs.Branch.create(project_b, name: "project-b-rbac-branch")
      hook_b = Support.Stubs.Hook.create(branch_b)
      workflow_b = Support.Stubs.Workflow.create(hook_b, user)
      Support.Stubs.Pipeline.create_initial(workflow_b)

      workflow_a = DB.first(:workflows) |> then(&Front.Models.Workflow.find(&1.id))
      workflow_b = Front.Models.Workflow.find(workflow_b.id)

      {:ok, seq} = Agent.start_link(fn -> 0 end)

      with_mocks [
        {Front.RBAC.Members, [:passthrough],
         [
           list_accessible_projects: fn _org_id, _user_id ->
             Agent.get_and_update(seq, fn call_idx ->
               if call_idx == 0 do
                 {{:ok, [project.id, project_b.id]}, 1}
               else
                 {{:ok, [project.id]}, call_idx + 1}
               end
             end)
           end
         ]},
        {Front.Models.Workflow, [:passthrough],
         [
           list_keyset: fn params ->
             send(self(), {:list_keyset_project_ids, params[:project_ids]})

             workflows =
               [workflow_a, workflow_b]
               |> Enum.filter(fn workflow ->
                 Enum.member?(params[:project_ids], workflow.project_id)
               end)

             {workflows, "", ""}
           end
         ]}
      ] do
        first_conn =
          conn
          |> get("/?dashboard=everyones-activity")

        first_response = html_response(first_conn, 200)
        assert first_response =~ project.name
        assert first_response =~ project_b.name
        assert_received {:list_keyset_project_ids, first_project_ids}
        assert Enum.sort(first_project_ids) == Enum.sort([project.id, project_b.id])

        first_cache_key = cache_key(organization.id, user.id, false, [project.id, project_b.id])
        assert Cacheman.exists?(:front, first_cache_key)

        second_conn =
          first_conn
          |> recycle()
          |> get("/?dashboard=everyones-activity")

        second_response = html_response(second_conn, 200)
        assert second_response =~ project.name
        refute second_response =~ project_b.name
        assert_received {:list_keyset_project_ids, second_project_ids}
        assert second_project_ids == [project.id]

        second_cache_key = cache_key(organization.id, user.id, false, [project.id])
        assert Cacheman.exists?(:front, second_cache_key)
        refute first_cache_key == second_cache_key
      end
    end

    test "force_cold_boot bypasses cache", %{conn: conn, project: project} do
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
          |> get("/?force_cold_boot=true")

        assert html_response(conn, 200) =~ "Loading workflows timed out"
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

  defp cache_key(org_id, user_id, requester, project_ids) do
    params =
      struct!(Model.LoadParams,
        organization_id: org_id,
        user_id: user_id,
        requester: requester,
        project_ids_fingerprint: project_ids_fingerprint(project_ids)
      )

    Model.cache_key(params)
  end

  defp project_ids_fingerprint(project_ids) do
    project_ids
    |> Enum.uniq()
    |> Enum.sort()
    |> Enum.join(",")
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end
end
