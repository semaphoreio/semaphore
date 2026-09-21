defmodule PipelinesAPI.ServiceAccounts.RegenerateToken do
  @moduledoc false
  use Plug.Builder

  alias PipelinesAPI.Pipelines.Common, as: RespCommon
  alias PipelinesAPI.Util.Metrics
  alias PipelinesAPI.ServiceAccountClient
  alias PipelinesAPI.Audit

  import PipelinesAPI.ServiceAccounts.Authorize, only: [authorize_manage: 2]

  plug(:authorize_manage)
  plug(:regenerate_token)

  def regenerate_token(conn, _opts) do
    Metrics.benchmark("PipelinesAPI.router", ["service_account_regenerate_token"], fn ->
      conn.params
      |> ServiceAccountClient.regenerate_token(conn)
      |> tap(fn result -> audit_event(result, conn) end)
      |> RespCommon.respond(conn)
    end)
  end

  defp audit_event({:ok, _result}, conn) do
    conn
    |> Audit.new(:ServiceAccount, :Rebuild)
    |> Audit.add(resource_id: conn.params["id"])
    |> Audit.log()
  end

  defp audit_event(_result, _conn), do: :ok
end
