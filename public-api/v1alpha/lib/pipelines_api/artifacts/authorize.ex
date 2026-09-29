defmodule PipelinesAPI.Artifacts.Authorize do
  @moduledoc """
  Authorization helpers for artifacts API endpoints.
  """

  use Plug.Builder

  alias PipelinesAPI.RBACClient
  alias LogTee, as: LT
  alias Plug.Conn

  @list_permissions ["project.view", "project.artifacts.view"]
  @signed_url_permissions ["project.view", "project.artifacts.view"]

  def authorize_list(conn, _opts) do
    authorize_with_permissions(conn, @list_permissions)
  end

  def authorize_signed_url(conn, _opts) do
    authorize_with_permissions(conn, @signed_url_permissions)
  end

  defp authorize_with_permissions(conn, required_permissions) do
    case conn.params["project_id"] do
      project_id when is_binary(project_id) and project_id != "" ->
        authorize(project_id, required_permissions, conn)

      _ ->
        LT.error("project_id missing in artifacts authorization params", "Artifacts.Authorize")
        conn |> authorization_failed(:internal)
    end
  end

  defp authorize(project_id, required_permissions, conn) do
    user_id = Conn.get_req_header(conn, "x-semaphore-user-id") |> Enum.at(0, "")
    org_id = Conn.get_req_header(conn, "x-semaphore-org-id") |> Enum.at(0, "")

    with params <- %{user_id: user_id, org_id: org_id, project_id: project_id},
         :ok <- PipelinesAPI.Util.Auth.project_belongs_to_org(org_id, project_id),
         {:ok, permissions} <- RBACClient.list_user_permissions(params) do
      authorize_or_halt(permissions, required_permissions, conn)
    else
      {:error, {:internal, _}} = error ->
        LT.error(error, "Artifacts.Authorize")
        conn |> authorization_failed(:internal)

      error ->
        LT.error(error, "Artifacts.Authorize")
        conn |> authorization_failed(:user)
    end
  end

  defp authorize_or_halt(permissions, required_permissions, conn) do
    if Enum.all?(required_permissions, &Enum.member?(permissions, &1)) do
      conn
    else
      conn |> authorization_failed(:unauthorized, "Permission denied")
    end
  end

  defp authorization_failed(conn, :unauthorized, msg), do: conn |> resp(401, msg) |> halt()
  defp authorization_failed(conn, :internal), do: conn |> resp(500, "Internal error") |> halt()
  defp authorization_failed(conn, :user), do: conn |> resp(404, "Not found") |> halt()
end
