defmodule PipelinesAPI.Schedules.Describe do
  @moduledoc """
  Plug which serves for describing schedules/periodics
  """

  use Plug.Builder

  alias PipelinesAPI.Pipelines.Common, as: RespCommon
  alias PipelinesAPI.Util.Metrics
  alias PipelinesAPI.PeriodicSchedulerClient

  import PipelinesAPI.Schedules.Authorize, only: [authorize_read: 2]
  import PipelinesAPI.Schedules.Common, only: [get_project_id: 2]

  plug(:identify_path_param)
  plug(:get_project_id)
  plug(:authorize_read)
  plug(:describe)

  def describe(conn, _opts) do
    Metrics.benchmark("PipelinesAPI.router", ["periodic_describe"], fn ->
      conn.params
      |> PeriodicSchedulerClient.describe(conn)
      |> RespCommon.respond(conn)
    end)
  end

  def identify_path_param(conn, _opts) do
    case UUID.info(conn.params["identifier"]) do
      {:ok, _} ->
        put_param_in_conn(conn, "periodic_id", conn.params["identifier"])

      _ ->
        {:error, {:user, "schedule identifier should be a UUID"}}
        |> RespCommon.respond(conn)
        |> halt()
    end
  end

  defp put_param_in_conn(conn, key, value) do
    params = conn.params |> Map.put(key, value)
    Map.put(conn, :params, params)
  end
end
