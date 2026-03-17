defmodule PipelinesAPI.Artifacts.Authorize do
  @moduledoc """
  Authorization helpers for artifacts API endpoints.
  """

  use Plug.Builder

  alias PipelinesAPI.Artifacts.Common, as: ArtifactsCommon
  alias PipelinesAPI.RBACClient
  alias LogTee, as: LT
  alias Plug.Conn

  def authorize_view(conn, _opts) do
    with {:ok, project_id} <- get_project_id(conn),
         conn <- put_project_id(conn, project_id) do
      authorize(project_id, "project.artifacts.view", conn)
    else
      {:error, {:internal, _}} = error ->
        LT.error(error, "Artifacts.Authorize")
        conn |> authorization_failed(:internal)

      error ->
        LT.error(error, "Artifacts.Authorize")
        conn |> authorization_failed(:user)
    end
  end

  defp authorize(project_id, permission, conn) do
    user_id = Conn.get_req_header(conn, "x-semaphore-user-id") |> Enum.at(0, "")
    org_id = Conn.get_req_header(conn, "x-semaphore-org-id") |> Enum.at(0, "")

    with params <- %{user_id: user_id, org_id: org_id, project_id: project_id},
         :ok <- PipelinesAPI.Util.Auth.project_belongs_to_org(org_id, project_id),
         {:ok, permissions} <- RBACClient.list_user_permissions(params) do
      authorize_or_halt(permissions, permission, conn)
    else
      {:error, {:internal, _}} = error ->
        LT.error(error, "Artifacts.Authorize")
        conn |> authorization_failed(:internal)

      error ->
        LT.error(error, "Artifacts.Authorize")
        conn |> authorization_failed(:user)
    end
  end

  defp get_project_id(%{params: %{"project_id" => project_id}})
       when is_binary(project_id) and project_id != "" do
    {:ok, project_id}
  end

  defp get_project_id(conn) do
    ArtifactsCommon.project_id_from_scope(conn.params)
  end

  defp put_project_id(conn, project_id) do
    conn
    |> Map.put(:params, Map.put(conn.params, "project_id", project_id))
  end

  defp authorize_or_halt(permissions, permission, conn) do
    if Enum.member?(permissions, permission) do
      conn
    else
      conn |> authorization_failed(:unathorized, "Permission denied")
    end
  end

  defp authorization_failed(conn, :unathorized, msg), do: conn |> resp(401, msg) |> halt()
  defp authorization_failed(conn, :internal), do: conn |> resp(500, "Internal error") |> halt()
  defp authorization_failed(conn, :user), do: conn |> resp(404, "Not found") |> halt()
end
