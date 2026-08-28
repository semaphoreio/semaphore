defmodule PipelinesAPI.Insights.Frequency do
  @moduledoc "GET /projects/:project_id/insights/frequency"

  use Plug.Builder

  alias PipelinesAPI.VelocityClient
  alias PipelinesAPI.Pipelines.Common, as: RespCommon
  alias PipelinesAPI.Util.Metrics

  import PipelinesAPI.Insights.Common, only: [track_request_metrics: 2, feature_enabled: 2]
  import PipelinesAPI.Insights.Authorize, only: [authorize_read: 2]

  plug(:track_request_metrics)
  plug(:feature_enabled)
  plug(:authorize_read)
  plug(:show)

  def show(conn, _opts) do
    Metrics.benchmark("PipelinesAPI.router", ["insights_frequency"], fn ->
      conn.params
      |> VelocityClient.list_pipeline_frequency_metrics()
      |> RespCommon.respond(conn)
    end)
  end
end
