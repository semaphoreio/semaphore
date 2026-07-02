defmodule PipelinesAPI.Groups.Create do
  @moduledoc false
  use Plug.Builder

  alias PipelinesAPI.Pipelines.Common, as: RespCommon
  alias PipelinesAPI.Util.Metrics
  alias PipelinesAPI.GroupsClient
  alias PipelinesAPI.Audit

  import PipelinesAPI.Groups.Authorize, only: [authorize_manage_groups: 2]

  plug(:authorize_manage_groups)
  plug(:create_group)

  def create_group(conn, _opts) do
    Metrics.benchmark("PipelinesAPI.router", ["groups_create"], fn ->
      conn.params
      |> GroupsClient.create(conn)
      |> tap(fn result -> audit_event(result, conn) end)
      |> RespCommon.respond(conn)
    end)
  end

  defp audit_event({:ok, group}, conn) do
    conn
    |> Audit.new(:Group, :Added)
    |> Audit.add(resource_id: group.id, resource_name: group.name)
    |> Audit.log()
  end

  defp audit_event(_result, _conn), do: :ok
end
