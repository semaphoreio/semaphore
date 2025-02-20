defmodule PipelinesAPI.ArtifactsRetentionPolicy.Authorize do
  @moduledoc """
  Plug checks authorization of the user for a given project.
  It checks if a user has ViewProjectSettings permission for the project, given by its id,
  so that the user can get retention policy of the project, or the user has ManageProjectSettings
  enabled which permits to create/update retention policies.
  """

  use Plug.Builder

  alias PipelinesAPI.RBACClient
  alias LogTee, as: LT
  alias Plug.Conn

  def authorize_view_retention_policy(conn, opts),
    do: authorize_operation("project.general_settings.view", conn, opts)

  def authorize_manage_retention_policy(conn, opts),
    do: authorize_operation("project.general_settings.manage", conn, opts)

  defp authorize_operation(permission, conn, _opts) do
    case conn.params["project_id"] do
      nil -> conn |> resp(400, "Bad Request: missing project_id parameter") |> halt
      project_id -> is_authorized?(project_id, permission, conn)
    end
  end

  defp is_authorized?(project_id, permission, conn) do
    with user_id <- Conn.get_req_header(conn, "x-semaphore-user-id") |> Enum.at(0, ""),
         org_id <- Conn.get_req_header(conn, "x-semaphore-org-id") |> Enum.at(0, ""),
         :ok <- PipelinesAPI.Util.Auth.project_belongs_to_org(org_id, project_id),
         params <- %{user_id: user_id, org_id: org_id, project_id: project_id},
         {:ok, permissions} <- RBACClient.list_user_permissions(params) do
      authorize_or_halt(permissions, permission, conn)
    else
      {:error, {:internal, _}} = error ->
        LT.error(error, "ArtifactsRetentionPolicy.Authorize")
        conn |> authorization_failed(:internal)

      error ->
        LT.error(error, "ArtifactsRetentionPolicy.Authorize")
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
