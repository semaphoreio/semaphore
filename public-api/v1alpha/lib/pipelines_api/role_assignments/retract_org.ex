defmodule PipelinesAPI.RoleAssignments.RetractOrg do
  @moduledoc false
  use Plug.Builder

  alias PipelinesAPI.Pipelines.Common, as: RespCommon
  alias PipelinesAPI.Util.Metrics
  alias PipelinesAPI.RBACClient
  alias Plug.Conn

  import PipelinesAPI.Members.Authorize, only: [authorize_manage_people: 2]

  plug(:authorize_manage_people)
  plug(:retract_role)

  def retract_role(conn, _opts) do
    Metrics.benchmark("PipelinesAPI.router", ["role_retract_org"], fn ->
      org_id = Conn.get_req_header(conn, "x-semaphore-org-id") |> Enum.at(0, "")
      requester_id = Conn.get_req_header(conn, "x-semaphore-user-id") |> Enum.at(0, "")

      %{
        user_id: conn.params["subject_id"],
        org_id: org_id,
        requester_id: requester_id,
        role_id: conn.params["role_id"]
      }
      |> RBACClient.retract_role()
      |> RespCommon.respond(conn)
    end)
  end
end
