defmodule PipelinesAPI.Schedules.Apply do
  @moduledoc """
  Plug which serves for applying given yaml config with schedule definition
  """

  use Plug.Builder

  alias PipelinesAPI.Pipelines.Common, as: RespCommon
  alias PipelinesAPI.Util.Metrics
  alias PipelinesAPI.PeriodicSchedulerClient

  import PipelinesAPI.Schedules.Authorize, only: [authorize_apply: 2]
  import PipelinesAPI.Schedules.Common, only: [get_project_id: 2]

  plug(:get_project_id)
  plug(:authorize_apply)
  plug(:apply_yml_def)

  def apply_yml_def(conn, _opts) do
    Metrics.benchmark("PipelinesAPI.router", ["periodic_apply"], fn ->
      conn.params
      |> PeriodicSchedulerClient.apply(conn)
      |> RespCommon.respond(conn)
    end)
  end
end
