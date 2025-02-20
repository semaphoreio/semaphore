defmodule FrontWeb.ErrorViewTest do
  use FrontWeb.ConnCase

  # Bring render/3 and render_to_string/3 for testing custom views
  import Phoenix.View
  import Phoenix.HTML, only: [safe_to_string: 1]

  test "renders 404.html for anonymous" do
    conn =
      build_conn()
      |> put_req_header("x-semaphore-user-anonymous", "true")
      |> get("/xxx")

    assert html_response(conn, 404) =~ "Not Found"
    assert html_response(conn, 404) =~ "Sign up"
  end

  test "renders 404.html for user" do
    conn =
      build_conn()
      |> put_req_header("x-semaphore-user-anonymous", "false")
      |> get("/xxx")

    assert html_response(conn, 404) =~ "Not Found"
    refute html_response(conn, 404) =~ "Sign up"
  end

  test "renders 500.html" do
    html = render(FrontWeb.ErrorView, "500.html", [])
    assert safe_to_string(html) =~ "Internal Server Error"
  end
end
