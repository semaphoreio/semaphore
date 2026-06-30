defmodule PipelinesAPI.RoleAssignments.RetractProject do
  @moduledoc false
  use Plug.Builder

  alias PipelinesAPI.Pipelines.Common, as: RespCommon
  alias PipelinesAPI.Util.Metrics
  alias PipelinesAPI.RBACClient
  alias Plug.Conn

  import PipelinesAPI.RoleAssignments.AuthorizeProject, only: [authorize_manage_project_access: 2]

  plug(:authorize_manage_project_access)
  plug(:retract_project_role)

  def retract_project_role(conn, _opts) do
    Metrics.benchmark("PipelinesAPI.router", ["role_retract_project"], fn ->
      org_id = Conn.get_req_header(conn, "x-semaphore-org-id") |> Enum.at(0, "")
      requester_id = Conn.get_req_header(conn, "x-semaphore-user-id") |> Enum.at(0, "")

      %{
        user_id: conn.params["subject_id"],
        org_id: org_id,
        project_id: conn.params["project_id"],
        requester_id: requester_id,
        role_id: conn.params["role_id"]
      }
      |> RBACClient.retract_project_role()
      |> RespCommon.respond(conn)
    end)
  end
end
