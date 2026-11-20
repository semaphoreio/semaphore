# credo:disable-for-this-file Credo.Check.Design.DuplicatedCode
defmodule FrontWeb.ActivityMonitorControllerTest do
  @moduledoc """
    Here we are testing access restrictions based on permissions.
    The rest of the activity_monitor related tests are performed inside other scripts
  """
  use FrontWeb.ConnCase
  import Mock
  alias Support.Stubs.DB

  setup %{conn: conn} do
    Cacheman.clear(:front)

    Support.Stubs.init()
    Support.Stubs.build_shared_factories()
    Support.Stubs.PermissionPatrol.remove_all_permissions()

    user = DB.first(:users)
    user_id = Map.get(user, :id)

    organization = DB.first(:organizations)
    organization_id = Map.get(organization, :id)

    conn =
      conn
      |> put_req_header("x-semaphore-org-id", organization_id)
      |> put_req_header("x-semaphore-user-id", user_id)

    [
      conn: conn,
      organization_id: organization_id,
      user_id: user_id
    ]
  end

  describe "index" do
    test "returns 404 if user cant access organization", %{conn: conn} do
      conn =
        conn
        |> get(activity_monitor_path(conn, :index))

      assert html_response(conn, 404)
    end

    test "If user can't view activity monitor, show appropriate message", %{conn: conn} = ctx do
      with_mock Front.ActivityMonitor, load: fn _, _ -> [] end do
        add_permissions(ctx, ["organization.view"])

        conn =
          conn
          |> get(activity_monitor_path(conn, :index))

        assert html_response(conn, 200) =~ "Sorry, you can’t access Activity Monitor."
      end
    end

    test "If user can view okta settings, but can't manage them", %{conn: conn} = ctx do
      with_mock Front.ActivityMonitor, load: fn _, _ -> [] end do
        add_permissions(ctx, ["organization.view", "organization.activity_monitor.view"])

        conn =
          conn
          |> get(activity_monitor_path(conn, :index))

        assert html_response(conn, 200) =~ "Everything currently running across all projects"
      end
    end
  end

  describe "index when activity data cannot be loaded" do
    test "renders the page with empty activity instead of failing", %{conn: conn} = ctx do
      with_mock Front.ActivityMonitor.Repo, load: fn _, _, _ -> {:error, rpc_error()} end do
        add_permissions(ctx, ["organization.view", "organization.activity_monitor.view"])

        conn = get(conn, activity_monitor_path(conn, :index))

        assert html_response(conn, 200) =~ "Everything currently running across all projects"
      end
    end
  end

  describe "activity_data" do
    test "returns 404 without activity monitor permission", %{conn: conn} = ctx do
      add_permissions(ctx, ["organization.view"])

      conn = get(conn, activity_monitor_path(conn, :activity_data))

      assert conn.status == 404
    end

    test "returns the activity as JSON", %{conn: conn} = ctx do
      with_mock Front.ActivityMonitor.Repo, load: fn _, _, _ -> {:ok, repo_data()} end do
        add_permissions(ctx, ["organization.view", "organization.activity_monitor.view"])

        conn = get(conn, activity_monitor_path(conn, :activity_data))

        assert %{
                 "org_name" => "TestOrg",
                 "agent_stats" => %{"agent_types" => _},
                 "items" => %{
                   "lobby" => %{"items" => [], "non_visible_pipelines_count" => 0},
                   "waiting" => %{"items" => [], "non_visible_job_count" => 0},
                   "running" => %{"items" => [], "non_visible_job_count" => 0}
                 }
               } = json_response(conn, 200)
      end
    end

    test "returns 503 with an error message when loading fails", %{conn: conn} = ctx do
      with_mock Front.ActivityMonitor.Repo, load: fn _, _, _ -> {:error, rpc_error()} end do
        add_permissions(ctx, ["organization.view", "organization.activity_monitor.view"])

        conn = get(conn, activity_monitor_path(conn, :activity_data))

        assert %{"error" => "Activity data is temporarily unavailable"} = json_response(conn, 503)
      end
    end
  end

  defp rpc_error, do: %GRPC.RPCError{status: 4, message: "deadline exceeded"}

  defp repo_data do
    %{
      org: %{name: "TestOrg"},
      accessable_projects: [],
      users: [],
      active_pipelines: [],
      active_jobs: [],
      active_debug_sessions: []
    }
  end

  defp add_permissions(ctx, permissions) do
    Support.Stubs.PermissionPatrol.add_permissions(
      ctx.organization_id,
      ctx.user_id,
      permissions
    )
  end
end
