defmodule PipelinesAPI.SharedAuthorize do
  @moduledoc false

  alias PipelinesAPI.RBACClient
  alias LogTee, as: LT
  alias Plug.Conn

  def check_permission(permission, conn) do
    user_id = Conn.get_req_header(conn, "x-semaphore-user-id") |> Enum.at(0, "")
    org_id = Conn.get_req_header(conn, "x-semaphore-org-id") |> Enum.at(0, "")

    if user_id == "" or org_id == "" do
      conn |> Plug.Conn.resp(404, "Not found") |> Plug.Conn.halt()
    else
      with params <- %{user_id: user_id, org_id: org_id},
           {:ok, permissions} <- RBACClient.list_user_permissions(params) do
        if Enum.member?(permissions, permission) do
          conn
        else
          conn |> Plug.Conn.resp(403, "Permission denied") |> Plug.Conn.halt()
        end
      else
        {:error, {:internal, _}} = error ->
          LT.error(error, "SharedAuthorize")
          conn |> Plug.Conn.resp(500, "Internal error") |> Plug.Conn.halt()

        error ->
          LT.error(error, "SharedAuthorize")
          conn |> Plug.Conn.resp(404, "Not found") |> Plug.Conn.halt()
      end
    end
  end
end
