defmodule FrontWeb.PageController do
  use FrontWeb, :controller

  plug(:accepts, ["html"])

  plug(:put_secure_browser_headers, %{
    "cross-origin-resource-policy" => "same-site",
    "cross-origin-opener-policy" => "same-origin",
    "cross-origin-embedder-policy" => "credentialless"
  })

  def is_alive(conn, _params) do
    Watchman.benchmark("health_check.duration", fn ->
      text(conn, "yes")
    end)
  end

  def status404(conn, _params) do
    # On onprem, if user isn't logged in, we want to redirect user to okta login
    # right away, without showing the 404 page
    if anonymous?(conn) == true and Front.os?() do
      conn
      |> put_resp_header("location", login_url(conn))
      |> send_resp(302, "")
    else
      conn
      |> Plug.Conn.put_status(:not_found)
      |> put_layout(false)
      |> put_view(FrontWeb.ErrorView)
      |> render("404.html")
    end
  end

  defdelegate anonymous?(conn), to: FrontWeb.ErrorView
  defdelegate login_url(conn), to: FrontWeb.LayoutView
end
