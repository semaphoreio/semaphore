defmodule PipelinesAPI.Schedules.List do
  @moduledoc """
  Plug which serves for listing schedules/periodics
  """

  use Plug.Builder

  alias PipelinesAPI.Pipelines.Common, as: RespCommon
  alias PipelinesAPI.Util.Metrics
  alias PipelinesAPI.PeriodicSchedulerClient

  import PipelinesAPI.Schedules.Authorize, only: [authorize_list_by_project_id: 2]

  plug(:put_project_id_to_assigns)
  plug(:authorize_list_by_project_id)
  plug(:list)

  def list(conn, _opts) do
    Metrics.benchmark("PipelinesAPI.router", ["periodic_list"], fn ->
      conn.params
      |> PeriodicSchedulerClient.list(conn)
      |> RespCommon.respond_paginated(conn)
    end)
  end

  defp put_project_id_to_assigns(conn, _opts) do
    project_id = conn.params["project_id"]
    Plug.Conn.assign(conn, :project_id, project_id)
  end
end
