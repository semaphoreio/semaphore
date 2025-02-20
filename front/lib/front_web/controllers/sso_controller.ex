defmodule FrontWeb.SSOController do
  use FrontWeb, :controller
  require Logger

  alias Front.{Async, Models}

  plug(FrontWeb.Plugs.OnPremBlocker)

  def zendesk(conn, params) do
    Watchman.benchmark("sso.zendesk.duration", fn ->
      user_id = conn.assigns.user_id
      return_to = params["return_to"]

      fetch_user = Async.run(fn -> Models.User.find(user_id) end)
      {:ok, user} = Async.await(fetch_user)

      conn
      |> put_layout(false)
      |> render("login_to_zendesk.html",
        jwt: Front.Zendesk.JWT.generate(user),
        url: Front.Zendesk.sso_location(return_to)
      )
    end)
  end
end
