defmodule PipelinesAPI.Groups.Destroy do
  @moduledoc false
  use Plug.Builder

  alias PipelinesAPI.Pipelines.Common, as: RespCommon
  alias PipelinesAPI.Util.Metrics
  alias PipelinesAPI.GroupsClient

  import PipelinesAPI.Groups.Authorize, only: [authorize_manage_groups: 2]

  plug(:authorize_manage_groups)
  plug(:destroy_group)

  def destroy_group(conn, _opts) do
    Metrics.benchmark("PipelinesAPI.router", ["groups_destroy"], fn ->
      conn.params
      |> GroupsClient.destroy(conn)
      |> RespCommon.respond(conn)
    end)
  end
end
