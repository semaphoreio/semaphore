defmodule PipelinesAPI.Groups.Authorize do
  @moduledoc false
  use Plug.Builder

  alias PipelinesAPI.RBACClient
  alias LogTee, as: LT
  alias Plug.Conn

  def authorize_view_groups(conn, _opts) do
    is_authorized?("organization.people.view", conn)
  end

  def authorize_manage_groups(conn, _opts) do
    is_authorized?("organization.people.manage", conn)
  end

  defp is_authorized?(permission, conn) do
    user_id = Conn.get_req_header(conn, "x-semaphore-user-id") |> Enum.at(0, "")
    org_id = Conn.get_req_header(conn, "x-semaphore-org-id") |> Enum.at(0, "")

    if user_id == "" or org_id == "" do
      conn |> resp(404, "Not found") |> halt
    else
      is_authorized_check(permission, conn, user_id, org_id)
    end
  end

  defp is_authorized_check(permission, conn, user_id, org_id) do
    with params <- %{user_id: user_id, org_id: org_id},
         {:ok, permissions} <- RBACClient.list_user_permissions(params) do
      if Enum.member?(permissions, permission) do
        conn
      else
        conn |> resp(403, "Permission denied") |> halt
      end
    else
      {:error, {:internal, _}} = error ->
        LT.error(error, "Groups.Authorize")
        conn |> resp(500, "Internal error") |> halt

      error ->
        LT.error(error, "Groups.Authorize")
        conn |> resp(404, "Not found") |> halt
    end
  end
end
