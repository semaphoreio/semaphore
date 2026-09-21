defmodule PipelinesAPI.TestResults.FlakyTestDetails do
  @moduledoc "GET /projects/:project_id/test_results/flaky_tests/:test_id"

  use Plug.Builder

  alias PipelinesAPI.SuperjerryClient
  alias PipelinesAPI.Pipelines.Common, as: RespCommon
  alias PipelinesAPI.Util.Metrics

  import PipelinesAPI.TestResults.Common,
    only: [track_request_metrics: 2, feature_enabled: 2, get_org_id: 1]

  import PipelinesAPI.TestResults.Authorize, only: [authorize_read: 2]

  plug(:track_request_metrics)
  plug(:feature_enabled)
  plug(:authorize_read)
  plug(:details)

  def details(conn, _opts) do
    Metrics.benchmark("PipelinesAPI.router", ["test_results_flaky_test_details"], fn ->
      org_id = get_org_id(conn)

      conn.params
      |> Map.put("org_id", org_id)
      |> SuperjerryClient.flaky_test_details()
      |> RespCommon.respond(conn)
    end)
  end
end
