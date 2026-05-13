defmodule PipelinesAPI.ServiceAccounts.Reactivate do
  @moduledoc false
  use Plug.Builder

  alias PipelinesAPI.Pipelines.Common, as: RespCommon
  alias PipelinesAPI.Util.Metrics
  alias PipelinesAPI.ServiceAccountClient

  import PipelinesAPI.ServiceAccounts.Authorize, only: [authorize_manage: 2]

  plug(:authorize_manage)
  plug(:reactivate_service_account)

  def reactivate_service_account(conn, _opts) do
    Metrics.benchmark("PipelinesAPI.router", ["service_account_reactivate"], fn ->
      conn.params
      |> ServiceAccountClient.reactivate(conn)
      |> RespCommon.respond(conn)
    end)
  end
end
