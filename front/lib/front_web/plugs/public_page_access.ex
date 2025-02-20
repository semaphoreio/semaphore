defmodule FrontWeb.Plugs.PublicPageAccess do
  @moduledoc """
    This plug is used to restrict access to project pages that can be public.
    Some of the public pages are: project page, workflow page, job page

    For restricting access to all of the other pages and endpoints, PageAccess plug should be used

    This plug should be called after the PutProjectAssigns plug and FetchPermissions plug.
  """
  require Logger

  def init(default), do: default

  def call(conn, _opts) do
    cond do
      conn.assigns.permissions["project.view"] ->
        Plug.Conn.assign(conn, :authorization, :member)

      conn.assigns.project.public ->
        Plug.Conn.assign(conn, :authorization, :guest)

      true ->
        conn |> render_404()
    end
  rescue
    e ->
      Logger.error("Error #{inspect(e)} while executing PublicPageAccess plug #{inspect(conn)}")
      conn |> render_404()
  end

  defp render_404(conn) do
    conn
    |> FrontWeb.PageController.status404(%{})
    |> Plug.Conn.halt()
  end
end
