defmodule PipelinesAPI.Deployments.Authorize do
  @moduledoc """
  Plug checks authorization of the user for a given project.
  It checks if a user has ViewDeploymentTargets permission for the project, given by its id,
  so that the user can list/describe deployment targets, or the user has ManageDeploymentTargets
  enabled which permits to create, delete, update, cordon and un-cordon deployment targets.
  """

  use Plug.Builder

  alias PipelinesAPI.RBACClient
  alias LogTee, as: LT
  alias Plug.Conn

  def authorize_view_project(conn, opts),
    do: authorize_operation("project.deployment_targets.view", conn, opts)

  def authorize_manage_project(conn, opts),
    do: authorize_operation("project.deployment_targets.manage", conn, opts)

  defp authorize_operation(permission, conn, _opts) do
    case conn.assigns[:project_id] do
      project_id when is_binary(project_id) and project_id != "" ->
        is_authorized?(permission, project_id, conn)

      _ ->
        conn |> resp(404, "Project not found") |> halt
    end
  end

  defp is_authorized?(permission, project_id, conn) do
    with user_id <- Conn.get_req_header(conn, "x-semaphore-user-id") |> Enum.at(0, ""),
         org_id <- Conn.get_req_header(conn, "x-semaphore-org-id") |> Enum.at(0, ""),
         :ok <- PipelinesAPI.Util.Auth.project_belongs_to_org(org_id, project_id),
         params <- %{user_id: user_id, org_id: org_id, project_id: project_id},
         {:ok, permissions} <- RBACClient.list_user_permissions(params) do
      authorize_or_halt(permissions, permission, conn)
    else
      {:error, {:internal, _}} = error ->
        LT.error(error, "Deployments.Authorize")
        conn |> authorization_failed(:internal)

      error ->
        LT.error(error, "Deployments.Authorize")
        conn |> authorization_failed(:user)
    end
  end

  defp authorize_or_halt(permissions, permission, conn) do
    if Enum.member?(permissions, permission) do
      conn
    else
      conn |> authorization_failed(:unathorized, "Permission denied")
    end
  end

  defp authorization_failed(conn, :unathorized, msg), do: conn |> resp(401, msg) |> halt
  defp authorization_failed(conn, :internal), do: conn |> resp(500, "Internal error") |> halt
  defp authorization_failed(conn, :user), do: conn |> resp(404, "Not found") |> halt
end
