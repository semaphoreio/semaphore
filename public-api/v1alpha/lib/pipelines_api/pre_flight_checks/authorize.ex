defmodule PipelinesAPI.PreFlightChecks.Authorize do
  @moduledoc """
  Plug checks authorization of the user for pre-flight checks configuration.

  When project_id is given, the check is scoped to that project and the project
  must belong to the organization from the request. Otherwise the check is
  scoped to the organization.
  """

  use Plug.Builder

  alias PipelinesAPI.RBACClient
  alias LogTee, as: LT
  alias Plug.Conn

  def authorize_view(conn = %{params: %{"project_id" => project_id}}, _opts)
      when is_binary(project_id) and project_id != "",
      do: authorize_project("project.pre_flight_checks.view", project_id, conn)

  def authorize_view(conn, _opts),
    do: authorize_organization("organization.pre_flight_checks.view", conn)

  def authorize_manage(conn = %{params: %{"project_id" => project_id}}, _opts)
      when is_binary(project_id) and project_id != "",
      do: authorize_project("project.pre_flight_checks.manage", project_id, conn)

  def authorize_manage(conn, _opts),
    do: authorize_organization("organization.pre_flight_checks.manage", conn)

  defp authorize_project(permission, project_id, conn) do
    with user_id <- Conn.get_req_header(conn, "x-semaphore-user-id") |> Enum.at(0, ""),
         org_id <- Conn.get_req_header(conn, "x-semaphore-org-id") |> Enum.at(0, ""),
         :ok <- PipelinesAPI.Util.Auth.project_belongs_to_org(org_id, project_id),
         params <- %{user_id: user_id, org_id: org_id, project_id: project_id},
         {:ok, permissions} <- RBACClient.list_user_permissions(params) do
      authorize_or_halt(permissions, permission, conn)
    else
      {:error, {:internal, _}} = error ->
        LT.error(error, "PreFlightChecks.Authorize")
        conn |> authorization_failed(:internal)

      error ->
        LT.error(error, "PreFlightChecks.Authorize")
        conn |> authorization_failed(:user)
    end
  end

  defp authorize_organization(permission, conn) do
    user_id = Conn.get_req_header(conn, "x-semaphore-user-id") |> Enum.at(0, "")
    org_id = Conn.get_req_header(conn, "x-semaphore-org-id") |> Enum.at(0, "")

    with params <- %{user_id: user_id, org_id: org_id},
         {:ok, permissions} <- RBACClient.list_user_permissions(params) do
      authorize_or_halt(permissions, permission, conn)
    else
      {:error, {:internal, _}} = error ->
        LT.error(error, "PreFlightChecks.Authorize")
        conn |> authorization_failed(:internal)

      error ->
        LT.error(error, "PreFlightChecks.Authorize")
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
