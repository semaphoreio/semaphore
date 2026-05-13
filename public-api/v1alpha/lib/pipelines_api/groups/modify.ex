defmodule PipelinesAPI.Groups.Modify do
  @moduledoc false
  use Plug.Builder

  alias PipelinesAPI.Pipelines.Common, as: RespCommon
  alias PipelinesAPI.Util.Metrics
  alias PipelinesAPI.GroupsClient

  import PipelinesAPI.Groups.Authorize, only: [authorize_manage_groups: 2]

  plug(:authorize_manage_groups)
  plug(:modify_group)

  def modify_group(conn, _opts) do
    Metrics.benchmark("PipelinesAPI.router", ["groups_modify"], fn ->
      conn.params
      |> GroupsClient.modify(conn)
      |> RespCommon.respond(conn)
    end)
  end
end
