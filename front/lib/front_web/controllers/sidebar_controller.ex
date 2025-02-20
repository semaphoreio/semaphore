defmodule FrontWeb.SidebarController do
  use FrontWeb, :controller

  plug(:put_layout, false)

  alias Front.Models

  def star(conn, params) do
    Watchman.benchmark("sidebar.star.duration", fn ->
      {:ok, _} =
        Models.User.star(
          conn.assigns.user_id,
          conn.assigns.organization_id,
          params["favorite_id"],
          params["kind"]
        )

      text(conn, "Starred")
    end)
  end

  def unstar(conn, params) do
    Watchman.benchmark("sidebar.unstar.duration", fn ->
      {:ok, _} =
        Models.User.unstar(
          conn.assigns.user_id,
          conn.assigns.organization_id,
          params["favorite_id"],
          params["kind"]
        )

      text(conn, "Unstarred")
    end)
  end
end
