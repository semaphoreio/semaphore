defmodule PipelinesAPI.ServiceAccounts.Destroy do
  @moduledoc false
  use Plug.Builder

  alias PipelinesAPI.Pipelines.Common, as: RespCommon
  alias PipelinesAPI.Util.Metrics
  alias PipelinesAPI.ServiceAccountClient
  alias PipelinesAPI.Audit

  import PipelinesAPI.ServiceAccounts.Authorize, only: [authorize_manage: 2]

  plug(:authorize_manage)
  plug(:destroy_service_account)

  def destroy_service_account(conn, _opts) do
    Metrics.benchmark("PipelinesAPI.router", ["service_account_destroy"], fn ->
      conn.params
      |> ServiceAccountClient.destroy(conn)
      |> tap(fn result -> audit_event(result, conn) end)
      |> RespCommon.respond(conn)
    end)
  end

  defp audit_event({:ok, _result}, conn) do
    conn
    |> Audit.new(:ServiceAccount, :Removed)
    |> Audit.add(resource_id: conn.params["id"])
    |> Audit.log()
  end

  defp audit_event(_result, _conn), do: :ok
end
