defmodule PipelinesAPI.Insights.Common do
  @moduledoc "Shared plugs for insights endpoints: feature-flag gate and request metrics."

  use Plug.Builder

  alias PipelinesAPI.Util.RequestMetrics
  alias Plug.Conn

  def track_request_metrics(conn, _opts) do
    RequestMetrics.track_request(conn, "insights_api_request")
  end

  def get_org_id(conn) do
    Conn.get_req_header(conn, "x-semaphore-org-id") |> Enum.at(0, "")
  end

  def feature_enabled(conn, _opts) do
    org_id = get_org_id(conn)

    if org_id != "" and FeatureProvider.feature_enabled?(:pipeline_summaries, param: org_id) do
      conn
    else
      conn |> resp(404, "Not Found") |> halt()
    end
  end
end
