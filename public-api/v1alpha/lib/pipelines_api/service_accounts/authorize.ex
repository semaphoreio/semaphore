defmodule PipelinesAPI.ServiceAccounts.Authorize do
  @moduledoc false
  use Plug.Builder

  alias PipelinesAPI.RBACClient
  alias LogTee, as: LT
  alias Plug.Conn

  def authorize_manage(conn, _opts) do
    is_authorized?("organization.service_accounts.manage", conn)
  end

  def authorize_view(conn, _opts) do
    is_authorized?("organization.service_accounts.view", conn)
  end

  defp is_authorized?(permission, conn) do
    user_id = Conn.get_req_header(conn, "x-semaphore-user-id") |> Enum.at(0, "")
    org_id = Conn.get_req_header(conn, "x-semaphore-org-id") |> Enum.at(0, "")

    if user_id == "" or org_id == "" do
      conn |> authorization_failed(:user)
    else
      is_authorized_check(permission, conn, user_id, org_id)
    end
  end

  defp is_authorized_check(permission, conn, user_id, org_id) do
    with params <- %{user_id: user_id, org_id: org_id},
         {:ok, permissions} <- RBACClient.list_user_permissions(params) do
      authorize_or_halt(permissions, permission, conn)
    else
      {:error, {:internal, _}} = error ->
        LT.error(error, "ServiceAccounts.Authorize")
        conn |> authorization_failed(:internal)

      error ->
        LT.error(error, "ServiceAccounts.Authorize")
        conn |> authorization_failed(:user)
    end
  end

  defp authorize_or_halt(permissions, permission, conn) do
    if Enum.member?(permissions, permission) do
      conn
    else
      conn |> authorization_failed(:forbidden, "Permission denied")
    end
  end

  defp authorization_failed(conn, :forbidden, msg), do: conn |> resp(403, msg) |> halt
  defp authorization_failed(conn, :internal), do: conn |> resp(500, "Internal error") |> halt
  defp authorization_failed(conn, :user), do: conn |> resp(404, "Not found") |> halt
end
