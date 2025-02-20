defmodule FrontWeb.Plugs.PageAccess do
  @moduledoc """
    This plug should be called after the FetchPermissions plug. It is expected for
    user's permissions to already be present in the assigns.

    When calling the plug a list of permissions is given.
    If any of those permissions is not present, 404 response is returned.
  """
  def init(default), do: default

  def call(conn, permissions: permissions) when not is_list(permissions),
    do: call(conn, permissions: [permissions])

  def call(conn, permissions: permissions) do
    if adequate_permissions_present?(conn, permissions) do
      Plug.Conn.assign(conn, :authorization, :member)
    else
      render404(conn)
    end
  end

  def call(_conn, _opts), do: raise("No permissions were passed to the plug")

  def adequate_permissions_present?(conn, permissions) do
    permissions
    |> Enum.map(&conn.assigns.permissions[&1])
    |> Enum.all?()
  end

  defp render404(conn) do
    conn
    |> FrontWeb.PageController.status404(%{})
    |> Plug.Conn.halt()
  end
end
