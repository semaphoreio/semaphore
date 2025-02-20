defmodule FrontWeb.SSOControllerTest do
  use FrontWeb.ConnCase
  import Mock

  setup do
    Cacheman.clear(:front)

    Support.Stubs.init()
    Support.Stubs.build_shared_factories()

    user = Support.Stubs.DB.first(:users)

    conn =
      build_conn(:get, "https://me.semaphoreci.com", nil)
      |> put_req_header("x-semaphore-user-id", user.id)

    %{conn: conn}
  end

  describe "zendesk/2" do
    test "renders the login_to_zendesk template with the correct assigns", %{conn: conn} do
      with_mock Front.Zendesk.JWT, generate: fn _ -> "test_jwt" end do
        conn = get(conn, "/sso/zendesk", %{"return_to" => "https://example.com/return_path"})

        html = html_response(conn, 200)
        assert html =~ "test_jwt"
        assert html =~ "/access/jwt?return_to=https://example.com/return_path"
      end
    end
  end
end
