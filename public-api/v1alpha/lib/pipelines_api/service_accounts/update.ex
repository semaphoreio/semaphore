defmodule PipelinesAPI.ServiceAccounts.Update do
  @moduledoc false
  use Plug.Builder

  alias PipelinesAPI.Pipelines.Common, as: RespCommon
  alias PipelinesAPI.Util.Metrics
  alias PipelinesAPI.ServiceAccountClient

  import PipelinesAPI.ServiceAccounts.Authorize, only: [authorize_manage: 2]

  plug(:authorize_manage)
  plug(:update_service_account)

  def update_service_account(conn, _opts) do
    Metrics.benchmark("PipelinesAPI.router", ["service_account_update"], fn ->
      conn.params
      |> ServiceAccountClient.update(conn)
      |> RespCommon.respond(conn)
    end)
  end
end
