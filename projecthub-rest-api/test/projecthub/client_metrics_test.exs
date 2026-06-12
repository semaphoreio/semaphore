defmodule Projecthub.ClientMetricsTest do
  use ExUnit.Case

  import ExUnit.CaptureIO

  alias Projecthub.ClientMetrics
  alias Plug.Test

  defp conn_with(headers) do
    Enum.reduce(headers, Test.conn(:get, "/api/v1alpha/projects"), fn {k, v}, conn ->
      Plug.Conn.put_req_header(conn, k, v)
    end)
  end

  defp emit(conn, status \\ 200) do
    conn = ClientMetrics.track_request(conn)
    output = capture_io(fn -> Plug.Conn.send_resp(conn, status, "") end)
    Jason.decode!(String.trim(output))
  end

  test "emits severity INFO and message client_request" do
    event = emit(conn_with([]))
    assert event["severity"] == "INFO"
    assert event["message"] == "client_request"
  end

  test "http_api pipeline skips health-check / probe paths (no event)" do
    for path <- ["/", "/is_alive"] do
      output = capture_io(fn -> Projecthub.HttpApi.call(Test.conn(:get, path), []) end)
      refute output =~ "client_request", "expected no event for #{path}"
    end
  end

  test "http_api pipeline tracks non-probe paths" do
    output = capture_io(fn -> Projecthub.HttpApi.call(Test.conn(:get, "/nonexistent"), []) end)
    assert output =~ "client_request"
  end

  test "known source semai-cli passes through" do
    event = emit(conn_with([{"x-client-source", "semai-cli"}]))
    assert event["client_source"] == "semai-cli"
  end

  test "known source semai-mcp passes through" do
    event = emit(conn_with([{"x-client-source", "semai-mcp"}]))
    assert event["client_source"] == "semai-mcp"
  end

  test "unknown source falls back to api" do
    event = emit(conn_with([{"x-client-source", "evil"}]))
    assert event["client_source"] == "api"
  end

  test "absent source falls back to api" do
    event = emit(conn_with([]))
    assert event["client_source"] == "api"
  end

  test "valid command passes through" do
    event = emit(conn_with([{"x-client-command", "project-list"}]))
    assert event["client_command"] == "project-list"
  end

  test "invalid command sanitised to na" do
    event = emit(conn_with([{"x-client-command", "DROP TABLE; rm -rf"}]))
    assert event["client_command"] == "na"
  end

  test "absent command is na" do
    event = emit(conn_with([]))
    assert event["client_command"] == "na"
  end

  test "valid version passes through" do
    event = emit(conn_with([{"x-client-version", "1.4.0"}]))
    assert event["client_version"] == "1.4.0"
  end

  test "absent version is na" do
    event = emit(conn_with([]))
    assert event["client_version"] == "na"
  end

  test "client_org_id from x-semaphore-org-id" do
    event = emit(conn_with([{"x-semaphore-org-id", "1bdc0370-a347-4cd6-8a01-1228ae6c6c83"}]))
    assert event["client_org_id"] == "1bdc0370-a347-4cd6-8a01-1228ae6c6c83"
  end

  test "client_org_id ignores x-semaphore-org-username" do
    event = emit(conn_with([{"x-semaphore-org-username", "acme-inc"}]))
    assert event["client_org_id"] == "na"
  end

  test "client_org_id is na when org-id absent" do
    event = emit(conn_with([]))
    assert event["client_org_id"] == "na"
  end

  test "no client_trace key emitted (projecthub does not track traces)" do
    event = emit(conn_with([]))
    refute Map.has_key?(event, "client_trace")
  end

  test "status reflects the HTTP response status" do
    event = emit(conn_with([]), 404)
    assert event["status"] == 404
  end

  test "duration_ms is a non-negative integer" do
    event = emit(conn_with([]))
    assert is_integer(event["duration_ms"])
    assert event["duration_ms"] >= 0
  end

  test "source/1 returns the raw source value for known sources" do
    assert ClientMetrics.source(conn_with([{"x-client-source", "semai-cli"}])) == "semai-cli"
  end

  test "org_id/1 returns the org id, ignoring username" do
    conn =
      conn_with([
        {"x-semaphore-org-username", "acme"},
        {"x-semaphore-org-id", "1bdc0370-a347-4cd6-8a01-1228ae6c6c83"}
      ])

    assert ClientMetrics.org_id(conn) == "1bdc0370-a347-4cd6-8a01-1228ae6c6c83"
  end

  test "builds [source, command, version] tags from sem-ai headers" do
    conn =
      conn_with([
        {"x-client-source", "semai-cli"},
        {"x-client-command", "project_list"},
        {"x-client-version", "1.4.0"}
      ])

    assert ClientMetrics.client_tags(conn) == ["semai-cli", "project_list", "1_4_0"]
  end

  test "neutralises dots AND plus in tag values (carbon-path safe)" do
    conn =
      conn_with([
        {"x-client-source", "semai-cli"},
        {"x-client-command", "project_list"},
        {"x-client-version", "v0.1.19+build.5"}
      ])

    assert ClientMetrics.client_tags(conn) == ["semai-cli", "project_list", "v0_1_19_build_5"]
  end

  test "defaults header-less (non sem-ai) traffic to source=api with na dimensions" do
    assert ClientMetrics.client_tags(conn_with([])) == ["api", "na", "na"]
  end

  test "sanitises command and version tags to bound Graphite cardinality" do
    conn =
      conn_with([
        {"x-client-source", "semai-cli"},
        {"x-client-command", "DROP TABLE; rm -rf"},
        {"x-client-version", "$(curl evil)"}
      ])

    assert ClientMetrics.client_tags(conn) == ["semai-cli", "na", "na"]
  end

  test "encodes status in the metric name suffix" do
    assert ClientMetrics.metric_name(200) == "Projecthub.router.client_request.ok"
    assert ClientMetrics.metric_name(404) == "Projecthub.router.client_request.client_error"
    assert ClientMetrics.metric_name(503) == "Projecthub.router.client_request.server_error"
    assert ClientMetrics.metric_name(nil) == "Projecthub.router.client_request.unknown"
  end
end
