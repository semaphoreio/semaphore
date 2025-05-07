defmodule CanvasFrontWeb.Plugs.InsiderPageAccess do
  @moduledoc """
    This plug should be called after the FetchPermissions plug. It is expected for
    user's permissions to already be present in the assigns.

    When calling the plug a list of permissions is given.
    If any of those permissions is not present, 404 response is returned.
  """

  @nil_uuid "00000000-0000-0000-0000-000000000000"

  def init(default), do: default

  def call(conn, _opts) do
    if insider?(conn) do
      conn
    else
      render404(conn)
    end
  end

  defp insider?(conn),
    do: Front.RBAC.Permissions.has?(conn.assigns.user_id, @nil_uuid, "insider.view")

  defp render404(conn) do
    conn
    |> Plug.Conn.put_status(:not_found)
    |> Phoenix.Controller.put_view(CanvasFrontWeb.ErrorHTML)
    |> Phoenix.Controller.render("404.html")
    |> Plug.Conn.halt()
  end
end
