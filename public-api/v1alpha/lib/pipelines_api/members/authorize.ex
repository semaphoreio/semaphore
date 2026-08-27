defmodule PipelinesAPI.Members.Authorize do
  @moduledoc false
  use Plug.Builder

  def authorize_view_people(conn, _opts),
    do: PipelinesAPI.SharedAuthorize.check_permission("organization.people.view", conn)

  def authorize_manage_people(conn, _opts),
    do: PipelinesAPI.SharedAuthorize.check_permission("organization.people.manage", conn)

  def authorize_view_project_people(conn, _opts) do
    project_id = conn.params["project_id"] || ""

    if project_id == "" do
      conn |> Plug.Conn.resp(404, "Not found") |> Plug.Conn.halt()
    else
      PipelinesAPI.SharedAuthorize.check_permission(
        "project.access.view",
        conn,
        %{project_id: project_id}
      )
    end
  end
end
