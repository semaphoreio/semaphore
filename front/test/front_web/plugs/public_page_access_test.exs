defmodule FrontWeb.Plugs.PublicPageAccessTest do
  use FrontWeb.ConnCase
  alias FrontWeb.Plugs.PublicPageAccess

  describe "call" do
    test "When permissions or project are not present in the assigns => show 404", %{conn: conn} do
      no_permissions_conn = conn |> PublicPageAccess.call([])
      assert html_response(no_permissions_conn, 404) =~ "404"

      no_project_conn = conn |> Plug.Conn.assign(:permissions, %{}) |> PublicPageAccess.call([])
      assert html_response(no_project_conn, 404) =~ "404"
    end

    test "When user has project_view permission", %{conn: conn} do
      conn =
        conn
        |> Plug.Conn.assign(:permissions, %{"project.view" => true})
        |> PublicPageAccess.call([])

      assert conn.assigns.authorization == :member
    end

    test "When project is public", %{conn: conn} do
      conn =
        conn
        |> Plug.Conn.assign(:permissions, %{"random.permission" => true})
        |> Plug.Conn.assign(:project, %{public: true})
        |> PublicPageAccess.call([])

      assert conn.assigns.authorization == :guest
    end

    test "When user does not have correct permissions, and project is private", %{conn: conn} do
      conn =
        conn
        |> Plug.Conn.assign(:permissions, %{"random.permission" => true})
        |> Plug.Conn.assign(:project, %{public: false})
        |> PublicPageAccess.call([])

      assert html_response(conn, 404) =~ "404"
    end
  end
end
