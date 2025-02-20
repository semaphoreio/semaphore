defmodule PipelinesAPI.Schedules.Authorize do
  @moduledoc """
    Plugs that check authorization and if authorization fails stop remaining plugs
  """

  use Plug.Builder

  alias PipelinesAPI.Util.Auth
  alias PipelinesAPI.RBACClient
  alias LogTee, as: LT
  alias Plug.Conn

  def authorize_apply(conn, _opts) do
    authorize("project.scheduler.manage", conn)
  end

  def authorize_run_now(conn, _opts) do
    authorize("project.scheduler.run_manually", conn)
  end

  def authorize_read(conn, _opts) do
    authorize("project.scheduler.view", conn)
  end

  def authorize_delete(conn, _opts) do
    authorize("project.scheduler.manage", conn)
  end

  def authorize_list_by_project_id(conn, opts) do
    case conn.params["project_id"] do
      nil ->
        # When listing by org_id and requester is added, this path will be ignored,
        # and authorization will be performed by filtering retreived periodics.
        conn |> authorization_failed(:user)

      _project_id ->
        authorize_read(conn, opts)
    end
  end

  defp authorize(permission, conn) do
    user_id = Conn.get_req_header(conn, "x-semaphore-user-id") |> Enum.at(0, "")
    org_id = Conn.get_req_header(conn, "x-semaphore-org-id") |> Enum.at(0, "")

    with project_id <- conn.assigns[:project_id],
         :ok <- Auth.project_belongs_to_org(org_id, project_id),
         ids <- collect_ids(user_id, org_id, project_id),
         {:ok, permissions} <- RBACClient.list_user_permissions(ids) do
      authorize_or_halt(permissions, permission, conn)
    else
      {:error, {:internal, _}} = error ->
        LT.error(error, "Schedules.Authorize")
        conn |> authorization_failed(:internal)

      error ->
        LT.error(error, "Schedules.Authorize")
        conn |> authorization_failed(:user)
    end
  end

  defp collect_ids(user_id, org_id, project_id) do
    %{user_id: user_id, org_id: org_id, project_id: project_id}
  end

  defp authorize_or_halt(permissions, permission, conn) do
    if Enum.member?(permissions, permission) do
      conn
    else
      conn |> authorization_failed(:user)
    end
  end

  defp authorization_failed(conn, :user), do: conn |> resp(404, "Not Found") |> halt
  defp authorization_failed(conn, :internal), do: conn |> resp(500, "Internal error") |> halt
end
