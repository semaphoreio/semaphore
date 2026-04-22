defmodule PipelinesAPI.Util.RequestMetricsTest do
  use ExUnit.Case

  alias PipelinesAPI.Util.RequestMetrics
  alias Plug.Test

  test "builds positional tags without prefixes" do
    conn =
      Test.conn(:get, "/api/v1alpha/artifacts")
      |> Plug.Conn.put_req_header("x-semaphore-org-id", "org-123")
      |> Plug.Conn.put_req_header("x-semaphore-user-id", "user-456")
      |> Map.put(:status, 302)

    assert RequestMetrics.metric_tags(conn) == [
             "302",
             "org-123",
             "user-456"
           ]
  end

  test "uses unknown placeholders for missing status and headers" do
    conn = Test.conn(:get, "/api/v1alpha/logs/job-id?artifact_job_logs=true")

    assert RequestMetrics.metric_tags(conn) == ["unknown", "unknown", "unknown"]
  end

  test "builds endpoint-specific metric name" do
    assert RequestMetrics.metric_name("artifacts_list_api_request") ==
             "PipelinesAPI.router.artifacts_list_api_request"
  end
end
