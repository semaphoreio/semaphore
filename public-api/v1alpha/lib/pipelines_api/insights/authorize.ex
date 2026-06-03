defmodule PipelinesAPI.Insights.Authorize do
  @moduledoc "Authorization plug for insights endpoints: project.view + cross-org gate."

  use Plug.Builder

  alias PipelinesAPI.RBACClient
  alias PipelinesAPI.Util.Auth
  alias LogTee, as: LT
  alias Plug.Conn

  @permission "project.view"

  def authorize_read(conn, _opts) do
    user_id = Conn.get_req_header(conn, "x-semaphore-user-id") |> Enum.at(0, "")
    org_id = Conn.get_req_header(conn, "x-semaphore-org-id") |> Enum.at(0, "")
    project_id = conn.params["project_id"]

    with :ok <- Auth.project_belongs_to_org(org_id, project_id),
         {:ok, permissions} <-
           RBACClient.list_user_permissions(%{
             user_id: user_id,
             org_id: org_id,
             project_id: project_id
           }) do
      if Enum.member?(permissions, @permission) do
        conn
      else
        authorization_failed(conn, :user)
      end
    else
      {:error, {:internal, _}} = error ->
        LT.error(error, "Insights.Authorize")
        authorization_failed(conn, :internal)

      error ->
        LT.error(error, "Insights.Authorize")
        authorization_failed(conn, :user)
    end
  end

  defp authorization_failed(conn, :user), do: conn |> resp(404, "Not Found") |> halt()
  defp authorization_failed(conn, :internal), do: conn |> resp(500, "Internal error") |> halt()
end
