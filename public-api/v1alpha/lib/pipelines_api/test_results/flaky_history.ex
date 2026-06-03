defmodule PipelinesAPI.TestResults.FlakyHistory do
  @moduledoc "GET /projects/:project_id/test_results/flaky_history"

  use Plug.Builder

  alias PipelinesAPI.SuperjerryClient
  alias PipelinesAPI.Pipelines.Common, as: RespCommon
  alias PipelinesAPI.Util.Metrics

  import PipelinesAPI.TestResults.Common, only: [track_request_metrics: 2, feature_enabled: 2]
  import PipelinesAPI.TestResults.Authorize, only: [authorize_read: 2]

  plug(:track_request_metrics)
  plug(:feature_enabled)
  plug(:authorize_read)
  plug(:history)

  def history(conn, _opts) do
    Metrics.benchmark("PipelinesAPI.router", ["test_results_flaky_history"], fn ->
      org_id = Plug.Conn.get_req_header(conn, "x-semaphore-org-id") |> Enum.at(0, "")

      conn.params
      |> Map.put("org_id", org_id)
      |> SuperjerryClient.list_flaky_history()
      |> RespCommon.respond(conn)
    end)
  end
end
