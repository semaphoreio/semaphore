defmodule PublicAPI.Plugs.Authorization.PermissionsChecker do
  @moduledoc """

  Plug for authorization of API requests.
  The plug uses user_id, org_id and project_id from conn.assigns
  and permissions set in opts to
  authorize the request.
  """

  require Logger

  alias Plug.Conn
  alias InternalClients.Permissions, as: PermissionsClient

  @unauthorized_error_message "Not Found"

  def authorize(conn, permissions) do
    org_id = conn.assigns[:organization_id]
    user_id = conn.assigns[:user_id]
    project_id = conn.assigns[:project_id] || ""

    PermissionsClient.has?(user_id, org_id, project_id, permissions)
    |> authorize_or_halt(
      permissions,
      conn
    )
  end

  defp authorize_or_halt(has_permissions, wanted_permissions, conn) do
    if Enum.all?(wanted_permissions, &Map.get(has_permissions, &1, false)) do
      conn
      |> Conn.assign(:authorized, true)
    else
      Watchman.increment({"Plug.Authorize.authorization_failed", ["user"]})

      PublicAPI.Util.ToTuple.not_found_error(@unauthorized_error_message)
      |> PublicAPI.Util.Response.respond(conn)
      |> Conn.assign(:authorized, false)
      |> Conn.halt()
    end
  end
end
