defmodule PipelinesAPI.ServiceAccounts.Deactivate do
  @moduledoc false
  use Plug.Builder

  alias PipelinesAPI.Pipelines.Common, as: RespCommon
  alias PipelinesAPI.Util.Metrics
  alias PipelinesAPI.ServiceAccountClient
  alias PipelinesAPI.Audit

  import PipelinesAPI.ServiceAccounts.Authorize, only: [authorize_manage: 2]

  plug(:authorize_manage)
  plug(:deactivate_service_account)

  def deactivate_service_account(conn, _opts) do
    Metrics.benchmark("PipelinesAPI.router", ["service_account_deactivate"], fn ->
      conn.params
      |> ServiceAccountClient.deactivate(conn)
      |> tap(fn result -> audit_event(result, conn) end)
      |> RespCommon.respond(conn)
    end)
  end

  defp audit_event({:ok, _result}, conn) do
    conn
    |> Audit.new(:ServiceAccount, :Disabled)
    |> Audit.add(resource_id: conn.params["id"])
    |> Audit.log()
  end

  defp audit_event(_result, _conn), do: :ok
end
