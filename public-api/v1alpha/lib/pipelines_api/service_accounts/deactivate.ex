defmodule PipelinesAPI.ServiceAccounts.Deactivate do
  @moduledoc false
  use Plug.Builder

  alias PipelinesAPI.Pipelines.Common, as: RespCommon
  alias PipelinesAPI.Util.Metrics
  alias PipelinesAPI.ServiceAccountClient

  import PipelinesAPI.ServiceAccounts.Authorize, only: [authorize_manage: 2]

  plug(:authorize_manage)
  plug(:deactivate_service_account)

  def deactivate_service_account(conn, _opts) do
    Metrics.benchmark("PipelinesAPI.router", ["service_account_deactivate"], fn ->
      conn.params
      |> ServiceAccountClient.deactivate(conn)
      |> RespCommon.respond(conn)
    end)
  end
end
