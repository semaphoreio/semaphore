defmodule FrontWeb.SupportControllerTest do
  use FrontWeb.ConnCase

  setup %{conn: conn} do
    Cacheman.clear(:front)

    Support.Stubs.init()
    Support.Stubs.build_shared_factories()

    user = Support.Stubs.User.default()
    organization = Support.Stubs.Organization.default()

    conn =
      conn
      |> put_req_header("x-semaphore-org-id", organization.id)
      |> put_req_header("x-semaphore-user-id", user.id)

    [
      conn: conn,
      organization: organization,
      user: user
    ]
  end

  describe "GET new" do
    test "when the user is not authorized to view the org, it renders 404", %{
      conn: conn,
      organization: _organization,
      user: _user
    } do
      Support.Stubs.PermissionPatrol.remove_all_permissions()

      conn =
        conn
        |> get("/support")

      assert html_response(conn, 404) =~ "404"
    end
  end

  describe "POST submit" do
    test "when the authorized user tries submitting the empty form, it shows the form errors", %{
      conn: conn
    } do
      conn =
        conn
        |> post("/support", %{})

      assert html_response(conn, 422) =~ "Select a topic first."
    end
  end
end
