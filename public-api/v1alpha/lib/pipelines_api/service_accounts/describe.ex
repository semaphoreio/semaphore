defmodule PipelinesAPI.ServiceAccounts.Describe do
  @moduledoc false
  use Plug.Builder

  alias PipelinesAPI.Pipelines.Common, as: RespCommon
  alias PipelinesAPI.Util.Metrics
  alias PipelinesAPI.ServiceAccountClient

  import PipelinesAPI.ServiceAccounts.Authorize, only: [authorize_view: 2]

  plug(:authorize_view)
  plug(:describe_service_account)

  def describe_service_account(conn, _opts) do
    Metrics.benchmark("PipelinesAPI.router", ["service_account_describe"], fn ->
      conn.params
      |> ServiceAccountClient.describe(conn)
      |> RespCommon.respond(conn)
    end)
  end
end
