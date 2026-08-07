defmodule PipelinesAPI.ServiceAccounts.List do
  @moduledoc false
  use Plug.Builder

  alias PipelinesAPI.Pipelines.Common, as: RespCommon
  alias PipelinesAPI.Util.Metrics
  alias PipelinesAPI.ServiceAccountClient

  import PipelinesAPI.ServiceAccounts.Authorize, only: [authorize_view: 2]

  plug(:authorize_view)
  plug(:list_service_accounts)

  def list_service_accounts(conn, _opts) do
    Metrics.benchmark("PipelinesAPI.router", ["service_account_list"], fn ->
      conn.params
      |> ServiceAccountClient.list(conn)
      |> RespCommon.respond(conn)
    end)
  end
end
