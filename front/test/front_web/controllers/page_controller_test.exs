defmodule FrontWeb.PageControllerTest do
  use FrontWeb.ConnCase

  test "GET /is_alive", %{conn: conn} do
    conn = get(conn, "/is_alive")
    assert text_response(conn, 200)
  end
end
