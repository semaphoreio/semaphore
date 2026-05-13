defmodule PipelinesAPI.ServiceAccounts.RegenerateToken do
  @moduledoc false
  use Plug.Builder

  alias PipelinesAPI.Pipelines.Common, as: RespCommon
  alias PipelinesAPI.Util.Metrics
  alias PipelinesAPI.ServiceAccountClient

  import PipelinesAPI.ServiceAccounts.Authorize, only: [authorize_manage: 2]

  plug(:authorize_manage)
  plug(:regenerate_token)

  def regenerate_token(conn, _opts) do
    Metrics.benchmark("PipelinesAPI.router", ["service_account_regenerate_token"], fn ->
      conn.params
      |> ServiceAccountClient.regenerate_token(conn)
      |> RespCommon.respond(conn)
    end)
  end
end
