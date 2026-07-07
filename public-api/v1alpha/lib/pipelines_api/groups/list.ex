defmodule PipelinesAPI.Groups.List do
  @moduledoc false
  use Plug.Builder

  alias PipelinesAPI.Pipelines.Common, as: RespCommon
  alias PipelinesAPI.Util.Metrics
  alias PipelinesAPI.GroupsClient

  import PipelinesAPI.Groups.Authorize, only: [authorize_view_groups: 2]

  plug(:authorize_view_groups)
  plug(:list_groups)

  def list_groups(conn, _opts) do
    Metrics.benchmark("PipelinesAPI.router", ["groups_list"], fn ->
      conn.params
      |> GroupsClient.list(conn)
      |> RespCommon.respond(conn)
    end)
  end
end
