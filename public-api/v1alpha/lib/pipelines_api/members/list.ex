defmodule PipelinesAPI.Members.List do
  @moduledoc false
  use Plug.Builder

  alias PipelinesAPI.Pipelines.Common, as: RespCommon
  alias PipelinesAPI.Util.Metrics
  alias PipelinesAPI.RBACClient
  alias Plug.Conn

  import PipelinesAPI.Members.Authorize, only: [authorize_view_people: 2]

  plug(:authorize_view_people)
  plug(:list_members)

  def list_members(conn, _opts) do
    Metrics.benchmark("PipelinesAPI.router", ["members_list"], fn ->
      org_id = Conn.get_req_header(conn, "x-semaphore-org-id") |> Enum.at(0, "")

      %{org_id: org_id}
      |> RBACClient.list_org_members()
      |> RespCommon.respond(conn)
    end)
  end
end
