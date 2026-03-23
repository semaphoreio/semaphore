defmodule PipelinesAPI.Logs.Authorize do
  @moduledoc """
  Plug that check authorization and if authorization fails stop remaining plugs
  """

  use Plug.Builder

  alias PipelinesAPI.Logs.Params, as: LogsParams
  alias PipelinesAPI.RBACClient
  alias LogTee, as: LT
  alias Plug.Conn

  def authorize_job(conn, _opts) do
    job = conn.params.job
    authorize(job.project_id, required_permissions(conn.params, job), conn)
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
        LT.error(error, "Logs.Authorize")
        conn |> authorization_failed(:internal)

      error ->
        LT.error(error, "Logs.Authorize")
        conn |> authorization_failed(:user)
    end
  end

  defp authorize_or_halt(permissions, required_permissions, conn) do
    if Enum.all?(required_permissions, &Enum.member?(permissions, &1)) do
      conn
    else
      conn |> authorization_failed(:unathorized, "Permission denied")
    end
  end

  defp required_permissions(params, job) do
    base_permissions = ["project.view"]

    if LogsParams.full_logs_requested_for_job?(params, job) do
      base_permissions ++ ["project.artifacts.view"]
    else
      base_permissions
    end
  end

  defp authorization_failed(conn, :unathorized, msg), do: conn |> resp(401, msg) |> halt
  defp authorization_failed(conn, :internal), do: conn |> resp(500, "Internal error") |> halt
  defp authorization_failed(conn, :user), do: conn |> resp(404, "Not found") |> halt
end
