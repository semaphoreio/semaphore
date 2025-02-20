defmodule PipelinesAPI.Promotions.List do
  @moduledoc """
  Plug which serves for listing all pipeline's promotions
  """

  use Plug.Builder

  alias PipelinesAPI.Pipelines.Common, as: RespCommon
  alias PipelinesAPI.Util.Metrics
  alias PipelinesAPI.GoferClient

  import PipelinesAPI.Pipelines.Authorize, only: [authorize_read: 2]
  import PipelinesAPI.Promotions.Common, only: [get_switch_id: 2]

  plug(:authorize_read)
  plug(:get_switch_id)
  plug(:list)

  def list(conn, _opts) do
    Metrics.benchmark("PipelinesAPI.router", ["gf_list"], fn ->
      conn.params
      |> GoferClient.list()
      |> RespCommon.respond_paginated(conn)
    end)
  end
end
