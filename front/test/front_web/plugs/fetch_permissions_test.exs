defmodule FrontWeb.Plugs.FetchPermissionsTest do
  use FrontWeb.ConnCase

  import Mock
  alias Front.RBAC.Permissions
  alias FrontWeb.Plugs.FetchPermissions

  @org_id Ecto.UUID.generate()
  @user_id Ecto.UUID.generate()

  setup %{conn: conn} do
    conn =
      conn
      |> Plug.Conn.assign(:user_id, @user_id)
      |> Plug.Conn.assign(:organization_id, @org_id)
      # Simulates a call to plug coming through a controller
      |> Map.merge(%{private: %{phoenix_controller: ""}})

    %{conn: conn}
  end

  describe "call" do
    test "When scope option is not specified or wrong, raise na error", %{conn: conn} do
      assert_raise(RuntimeError, "Scope must be either project or org", fn ->
        conn |> FetchPermissions.call([])
      end)

      assert_raise(RuntimeError, "Scope must be either project or org", fn ->
        conn |> FetchPermissions.call(scope: "random")
      end)
    end

    test "Fetch org scoped permissions", %{conn: conn} do
      with_mock Permissions, has?: fn _, _, _ -> %{"perm1" => true, "perm2" => false} end do
        conn = conn |> FetchPermissions.call(scope: "org")

        assert_called_exactly(Permissions.has?(@user_id, @org_id, []), 1)
        assert conn.assigns.permissions == %{"perm1" => true, "perm2" => false}
      end
    end

    @project_id Ecto.UUID.generate()
    test "Fetch project scoped permissions", %{conn: conn} do
      with_mocks([
        {Permissions, [], [has?: fn _, _, _, _ -> %{"perm1" => true, "perm2" => false} end]}
      ]) do
        conn =
          conn
          |> Plug.Conn.assign(:project, %{id: @project_id})
          |> FetchPermissions.call(scope: "project")

        assert_called_exactly(Permissions.has?(@user_id, @org_id, @project_id, []), 1)
        assert conn.assigns.permissions == %{"perm1" => true, "perm2" => false}
      end
    end
  end
end
