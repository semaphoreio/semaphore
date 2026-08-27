defmodule PipelinesAPI.RoleAssignments.AuthorizeProject do
  @moduledoc false
  use Plug.Builder

  alias PipelinesAPI.RBACClient
  alias LogTee, as: LT
  alias Plug.Conn

  def authorize_manage_project_access(conn, _opts) do
    user_id = Conn.get_req_header(conn, "x-semaphore-user-id") |> Enum.at(0, "")
    org_id = Conn.get_req_header(conn, "x-semaphore-org-id") |> Enum.at(0, "")
    project_id = conn.params["project_id"] || ""

    if user_id == "" or org_id == "" or project_id == "" do
      conn |> resp(404, "Not found") |> halt
    else
      with params <- %{user_id: user_id, org_id: org_id, project_id: project_id},
           {:ok, permissions} <- RBACClient.list_user_permissions(params) do
        if Enum.member?(permissions, "project.access.manage") do
          conn
        else
          conn |> resp(403, "Permission denied") |> halt
        end
      else
        {:error, {:internal, _}} = error ->
          LT.error(error, "RoleAssignments.AuthorizeProject")
          conn |> resp(500, "Internal error") |> halt

        error ->
          LT.error(error, "RoleAssignments.AuthorizeProject")
          conn |> resp(404, "Not found") |> halt
      end
    end
  end
end
