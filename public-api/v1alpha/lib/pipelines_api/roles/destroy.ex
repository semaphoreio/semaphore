defmodule PipelinesAPI.Roles.Destroy do
  @moduledoc false
  use Plug.Builder

  alias PipelinesAPI.Pipelines.Common, as: RespCommon
  alias PipelinesAPI.Util.Metrics
  alias PipelinesAPI.RBACClient
  alias Plug.Conn

  import PipelinesAPI.Roles.Authorize, only: [authorize_manage_roles: 2]

  plug(:authorize_manage_roles)
  plug(:destroy_role)

  def destroy_role(conn, _opts) do
    Metrics.benchmark("PipelinesAPI.router", ["roles_destroy"], fn ->
      org_id = Conn.get_req_header(conn, "x-semaphore-org-id") |> Enum.at(0, "")

      %{role_id: conn.params["id"], org_id: org_id}
      |> RBACClient.destroy_role()
      |> RespCommon.respond(conn)
    end)
  end
end
