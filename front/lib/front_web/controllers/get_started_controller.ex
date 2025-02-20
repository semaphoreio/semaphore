defmodule FrontWeb.GetStartedController do
  use FrontWeb, :controller

  plug(FrontWeb.Plugs.FeatureEnabled, [:get_started])
  @actions ~w(index signal)a

  plug(FrontWeb.Plugs.FetchPermissions, scope: "org")
  plug(FrontWeb.Plugs.PageAccess, permissions: "organization.view")
  plug(FrontWeb.Plugs.Header when action in @actions)

  def index(conn, _params) do
    organization_id = conn.assigns.organization_id
    user_id = conn.assigns.user_id

    Watchman.benchmark("get_started.index.duration", fn ->
      learn = Front.Onboarding.Learn.load(organization_id, user_id)

      conn
      |> render(
        "index.html",
        js: :getStarted,
        learn: learn,
        layout: {FrontWeb.LayoutView, "dashboard.html"}
      )
    end)
  end

  def signal(conn, params) do
    organization_id = conn.assigns.organization_id
    user_id = conn.assigns.user_id
    event_id = Map.get(params, "event_id")

    Front.Onboarding.Learn.mark(event_id, organization_id, user_id)
    |> case do
      :ok ->
        learn = Front.Onboarding.Learn.load(organization_id, user_id)

        conn
        |> put_status(200)
        |> json(%{learn: learn})

      _ ->
        conn
        |> put_status(500)
        |> json("error")
    end
  end
end
