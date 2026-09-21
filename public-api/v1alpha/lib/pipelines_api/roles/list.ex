defmodule PipelinesAPI.Roles.List do
  @moduledoc false
  use Plug.Builder

  alias PipelinesAPI.Pipelines.Common, as: RespCommon
  alias PipelinesAPI.Util.Metrics
  alias PipelinesAPI.RBACClient
  alias Plug.Conn

  import PipelinesAPI.Roles.Authorize, only: [authorize_view_roles: 2]

  plug(:authorize_view_roles)
  plug(:list_roles)

  def list_roles(conn, _opts) do
    Metrics.benchmark("PipelinesAPI.router", ["roles_list"], fn ->
      org_id = Conn.get_req_header(conn, "x-semaphore-org-id") |> Enum.at(0, "")

      %{org_id: org_id}
      |> RBACClient.list_org_roles()
      |> RespCommon.respond(conn)
    end)
  end
end
