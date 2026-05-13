defmodule PipelinesAPI.Groups.Create do
  @moduledoc false
  use Plug.Builder

  alias PipelinesAPI.Pipelines.Common, as: RespCommon
  alias PipelinesAPI.Util.Metrics
  alias PipelinesAPI.GroupsClient

  import PipelinesAPI.Groups.Authorize, only: [authorize_manage_groups: 2]

  plug(:authorize_manage_groups)
  plug(:create_group)

  def create_group(conn, _opts) do
    Metrics.benchmark("PipelinesAPI.router", ["groups_create"], fn ->
      conn.params
      |> GroupsClient.create(conn)
      |> RespCommon.respond(conn)
    end)
  end
end
