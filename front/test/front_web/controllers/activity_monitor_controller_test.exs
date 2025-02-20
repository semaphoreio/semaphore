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

  defp add_permissions(ctx, permissions) do
    Support.Stubs.PermissionPatrol.add_permissions(
      ctx.organization_id,
      ctx.user_id,
      permissions
    )
  end
end
