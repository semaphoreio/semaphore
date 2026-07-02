defmodule PipelinesAPI.ServiceAccounts.Update do
  @moduledoc false
  use Plug.Builder

  alias PipelinesAPI.Pipelines.Common, as: RespCommon
  alias PipelinesAPI.Util.Metrics
  alias PipelinesAPI.ServiceAccountClient
  alias PipelinesAPI.Audit

  import PipelinesAPI.ServiceAccounts.Authorize, only: [authorize_manage: 2]

  plug(:authorize_manage)
  plug(:update_service_account)

  def update_service_account(conn, _opts) do
    Metrics.benchmark("PipelinesAPI.router", ["service_account_update"], fn ->
      case ServiceAccountClient.describe(conn.params, conn) do
        {:ok, current} ->
          conn.params
          |> Map.put("name", conn.params["name"] || current.name)
          |> Map.put("description", conn.params["description"] || current.description)
          |> ServiceAccountClient.update(conn)
          |> tap(fn result -> audit_event(result, conn) end)
          |> RespCommon.respond(conn)

        error ->
          RespCommon.respond(error, conn)
      end
    end)
  end

  defp audit_event({:ok, sa}, conn) do
    conn
    |> Audit.new(:ServiceAccount, :Modified)
    |> Audit.add(resource_id: sa.id, resource_name: sa.name)
    |> Audit.log()
  end

  defp audit_event(_result, _conn), do: :ok
end
