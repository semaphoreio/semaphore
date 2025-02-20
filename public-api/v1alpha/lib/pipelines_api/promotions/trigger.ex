defmodule PipelinesAPI.Promotions.Trigger do
  @moduledoc """
  Plug which serves for triggering one pipeline's promotion target
  """

  use Plug.Builder

  alias PipelinesAPI.Pipelines.Common, as: RespCommon
  alias PipelinesAPI.Util.Metrics
  alias PipelinesAPI.GoferClient
  alias Plug.Conn

  import PipelinesAPI.Pipelines.Authorize, only: [authorize_create: 2]
  import PipelinesAPI.Promotions.Common, only: [get_switch_id: 2]

  plug(:authorize_create)
  plug(:get_switch_id)
  plug(:trigger)

  def trigger(conn, _opts) do
    Metrics.benchmark("PipelinesAPI.router", ["gf_trigger"], fn ->
      conn
      |> add_user_id()
      |> GoferClient.trigger()
      |> RespCommon.respond(conn)
    end)
  end

  defp add_user_id(conn) do
    user_id = Conn.get_req_header(conn, "x-semaphore-user-id") |> Enum.at(0, "")
    Map.put(conn.params, "user_id", user_id)
  end
end
