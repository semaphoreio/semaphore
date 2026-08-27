defmodule PipelinesAPI.Groups.Modify do
  @moduledoc false
  use Plug.Builder

  alias PipelinesAPI.Pipelines.Common, as: RespCommon
  alias PipelinesAPI.Util.Metrics
  alias PipelinesAPI.GroupsClient
  alias PipelinesAPI.Audit

  import PipelinesAPI.Groups.Authorize, only: [authorize_manage_groups: 2]

  plug(:authorize_manage_groups)
  plug(:modify_group)

  def modify_group(conn, _opts) do
    Metrics.benchmark("PipelinesAPI.router", ["groups_modify"], fn ->
      conn.params
      |> GroupsClient.modify(conn)
      |> tap(fn result -> audit_event(result, conn) end)
      |> RespCommon.respond(conn)
    end)
  end

  defp audit_event({:ok, group}, conn) do
    conn
    |> Audit.new(:Group, :Modified)
    |> Audit.add(resource_id: group.id, resource_name: group.name)
    |> Audit.log()
  end

  defp audit_event(_result, _conn), do: :ok
end
