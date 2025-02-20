defmodule FrontWeb.Plugs.PageTest do
  use FrontWeb.ConnCase
  alias FrontWeb.Plugs.PageAccess

  describe "call" do
    test "When no permissions are given, raise an error", %{conn: conn} do
      assert_raise(RuntimeError, "No permissions were passed to the plug", fn ->
        conn |> PageAccess.call([])
      end)
    end

    test "When one permission is given and present in assigns", %{conn: conn} do
      conn =
        conn
        |> Plug.Conn.assign(:permissions, %{"organization.view" => true})
        |> PageAccess.call(permissions: "organization.view")

      assert conn.assigns.authorization == :member
    end

    test "When only some permissions are present in the assigns", %{conn: conn} do
      org_conn =
        conn
        |> Plug.Conn.assign(:permissions, %{"organization.view" => true})
        |> PageAccess.call(permissions: ["organization.view", "organization.delete"])

      assert html_response(org_conn, 404) =~ "404"
    end

    test "When all permissions are present in the assigns", %{conn: conn} do
      conn =
        conn
        |> Plug.Conn.assign(:permissions, %{
          "organization.view" => true,
          "organization.delete" => true
        })
        |> PageAccess.call(permissions: ["organization.view", "organization.delete"])

      assert conn.assigns.authorization == :member
    end
  end
end
