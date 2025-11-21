defmodule FrontWeb.Plugs.FetchPermissions do
  @moduledoc """
    Fetches all the permissions user has, either within the organization, or within the specific project.

    The plug expects organization id, and user_id to be present in the assigns.
    If the plug is called with the "project" scope, the project needs to be in the assigns as well.
    The is a separate plug (PutProjectAssigns) which will put the project in the assigns or return 404
  """
  require Logger

  def init(default), do: default

  def call(conn, opts) do
    if opts[:scope] not in ["org", "project"] do
      raise("Scope must be either project or org")
    end

    conn
    |> fetch_permissions_for_controller(opts[:scope], conn.private.phoenix_controller)
  end

  defp fetch_permissions_for_controller(conn, scope, _), do: assign_permissions(conn, scope)

  defp assign_permissions(conn, scope, permissions \\ []) do
    user_id = conn.assigns.user_id
    org_id = conn.assigns.organization_id

    if is_nil(user_id) do
      Logger.info(
        "[FetchPermissions] Missing user_id while fetching permissions scope=#{scope} org_id=#{inspect(org_id)} path=#{conn.request_path}"
      )
    end

    if scope == "org" do
      Front.RBAC.Permissions.has?(user_id, org_id, permissions)
    else
      Front.RBAC.Permissions.has?(user_id, org_id, conn.assigns.project.id, permissions)
    end

    Plug.Conn.assign(conn, :permissions, has_permissions)
  end
end
