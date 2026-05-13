defmodule PipelinesAPI.RoleAssignments.AssignProject do
  @moduledoc false
  use Plug.Builder

  alias PipelinesAPI.Pipelines.Common, as: RespCommon
  alias PipelinesAPI.Util.Metrics
  alias PipelinesAPI.RBACClient
  alias Plug.Conn

  import PipelinesAPI.RoleAssignments.AuthorizeProject, only: [authorize_manage_project_access: 2]

  plug(:authorize_manage_project_access)
  plug(:assign_project_role)

  def assign_project_role(conn, _opts) do
    Metrics.benchmark("PipelinesAPI.router", ["role_assign_project"], fn ->
      org_id = Conn.get_req_header(conn, "x-semaphore-org-id") |> Enum.at(0, "")
      requester_id = Conn.get_req_header(conn, "x-semaphore-user-id") |> Enum.at(0, "")

      %{
        role_id: conn.params["role_id"],
        org_id: org_id,
        project_id: conn.params["project_id"],
        subject_id: conn.params["subject_id"],
        requester_id: requester_id
      }
      |> RBACClient.assign_role()
      |> RespCommon.respond(conn)
    end)
  end
end
