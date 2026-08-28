defmodule PipelinesAPI.Groups.Destroy do
  @moduledoc false
  use Plug.Builder

  alias PipelinesAPI.Pipelines.Common, as: RespCommon
  alias PipelinesAPI.Util.Metrics
  alias PipelinesAPI.GroupsClient
  alias PipelinesAPI.Audit

  import PipelinesAPI.Groups.Authorize, only: [authorize_manage_groups: 2]

  plug(:authorize_manage_groups)
  plug(:destroy_group)

  def destroy_group(conn, _opts) do
    Metrics.benchmark("PipelinesAPI.router", ["groups_destroy"], fn ->
      conn.params
      |> GroupsClient.destroy(conn)
      |> tap(fn result -> audit_event(result, conn) end)
      |> RespCommon.respond(conn)
    end)
  end

  defp audit_event({:ok, _result}, conn) do
    conn
    |> Audit.new(:Group, :Removed)
    |> Audit.add(resource_id: conn.params["id"])
    |> Audit.log()
  end

  defp audit_event(_result, _conn), do: :ok
end
