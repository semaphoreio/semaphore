defmodule PipelinesAPI.Util.ClientMetricsTest do
  use ExUnit.Case

  alias PipelinesAPI.Util.ClientMetrics
  alias Plug.Test

  defp conn_with(headers) do
    Enum.reduce(headers, Test.conn(:get, "/api/v1alpha/pipelines"), fn {k, v}, conn ->
      Plug.Conn.put_req_header(conn, k, v)
    end)
  end

  test "builds [source, command, version] tags from sem-ai headers" do
    conn =
      conn_with([
        {"x-semaphore-client-source", "semai-cli"},
        {"x-semaphore-client-command", "pipeline_list"},
        {"x-semaphore-client-version", "1.4.0"}
      ])

    assert ClientMetrics.client_tags(conn) == ["semai-cli", "pipeline_list", "1.4.0"]
  end

  test "defaults header-less (non sem-ai) traffic to source=api with na dimensions" do
    assert ClientMetrics.client_tags(conn_with([])) == ["api", "na", "na"]
  end

  test "accepts the mcp surface" do
    conn = conn_with([{"x-semaphore-client-source", "semai-mcp"}])
    assert ClientMetrics.source(conn) == "semai-mcp"
  end

  test "rejects an unknown source value, falling back to api" do
    conn = conn_with([{"x-semaphore-client-source", "evil-client"}])
    assert ClientMetrics.source(conn) == "api"
  end

  test "sanitises command and version to bound Graphite cardinality" do
    conn =
      conn_with([
        {"x-semaphore-client-source", "semai-cli"},
        {"x-semaphore-client-command", "DROP TABLE; rm -rf"},
        {"x-semaphore-client-version", "$(curl evil)"}
      ])

    assert ClientMetrics.client_tags(conn) == ["semai-cli", "na", "na"]
  end

  test "encodes status in the metric name suffix" do
    assert ClientMetrics.metric_name(200) == "PipelinesAPI.router.client_request.ok"
    assert ClientMetrics.metric_name(404) == "PipelinesAPI.router.client_request.client_error"
    assert ClientMetrics.metric_name(503) == "PipelinesAPI.router.client_request.server_error"
    assert ClientMetrics.metric_name(nil) == "PipelinesAPI.router.client_request.unknown"
  end

  test "log_fields renders compact client context" do
    conn =
      conn_with([
        {"x-semaphore-client-source", "semai-mcp"},
        {"x-semaphore-client-command", "diagnose"},
        {"x-semaphore-client-version", "1.4.0"}
      ])

    assert IO.iodata_to_binary(ClientMetrics.log_fields(conn)) ==
             " - client=semai-mcp command=diagnose version=1.4.0"
  end
end
