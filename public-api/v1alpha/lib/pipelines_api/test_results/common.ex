defmodule PipelinesAPI.TestResults.Common do
  @moduledoc "Shared plugs for test_results endpoints: feature-flag gate and request metrics."

  use Plug.Builder

  alias PipelinesAPI.Util.RequestMetrics
  alias Plug.Conn

  def track_request_metrics(conn, _opts) do
    RequestMetrics.track_request(conn, "test_results_api_request")
  end

  def feature_enabled(conn, _opts) do
    org_id = Conn.get_req_header(conn, "x-semaphore-org-id") |> Enum.at(0, "")

    if org_id != "" and FeatureProvider.feature_enabled?(:superjerry_tests, param: org_id) do
      conn
    else
      conn |> resp(404, "Not Found") |> halt()
    end
  end
end
