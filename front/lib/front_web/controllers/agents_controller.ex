defmodule FrontWeb.AgentsController do
  use FrontWeb, :controller
  require Logger

  if Application.compile_env(:front, :environment) == :dev do
    plug(FrontWeb.Plugs.Development.ActivityMonitor)
  end

  plug(FrontWeb.Plugs.FetchPermissions, scope: "org")
  plug(FrontWeb.Plugs.PageAccess, permissions: "organization.view")

  plug(
    FrontWeb.Plugs.Header
    when action in [
           :index,
           :show
         ]
  )

  plug(:put_layout, :organization)

  def index(conn, _params) do
    Watchman.benchmark("agents.index.duration", fn ->
      user_id = conn.assigns.user_id
      org_id = conn.assigns.organization_id

      activity = Front.ActivityMonitor.load(org_id, user_id)

      conn
      |> render("index.html",
        js: :agents,
        activity: activity
      )
    end)
  end
end
