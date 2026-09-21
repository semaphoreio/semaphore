defmodule PipelinesAPI.ServiceAccounts.Create do
  @moduledoc false
  use Plug.Builder

  alias PipelinesAPI.Pipelines.Common, as: RespCommon
  alias PipelinesAPI.Util.Metrics
  alias PipelinesAPI.ServiceAccountClient
  alias PipelinesAPI.Audit

  import PipelinesAPI.ServiceAccounts.Authorize, only: [authorize_manage: 2]

  plug(:authorize_manage)
  plug(:create_service_account)

  def create_service_account(conn, _opts) do
    Metrics.benchmark("PipelinesAPI.router", ["service_account_create"], fn ->
      conn.params
      |> ServiceAccountClient.create(conn)
      |> tap(fn result -> audit_event(result, conn) end)
      |> RespCommon.respond(conn)
    end)
  end

  defp audit_event({:ok, %{service_account: sa}}, conn) do
    conn
    |> Audit.new(:ServiceAccount, :Added)
    |> Audit.add(resource_id: sa.id, resource_name: sa.name)
    |> Audit.log()
  end

  defp audit_event(_result, _conn), do: :ok
end
