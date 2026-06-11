defmodule PipelinesAPI.Util.ClientMetricsTest do
  use ExUnit.Case

  import ExUnit.CaptureIO

  alias PipelinesAPI.Util.ClientMetrics
  alias Plug.Test

  defp conn_with(headers) do
    Enum.reduce(headers, Test.conn(:get, "/api/v1alpha/pipelines"), fn {k, v}, conn ->
      Plug.Conn.put_req_header(conn, k, v)
    end)
  end

  defp emit(conn, status \\ 200) do
    conn = ClientMetrics.track_request(conn)
    output = capture_io(fn -> Plug.Conn.send_resp(conn, status, "") end)
    Poison.decode!(String.trim(output))
  end

  test "emits severity INFO and message client_request" do
    event = emit(conn_with([]))
    assert event["severity"] == "INFO"
    assert event["message"] == "client_request"
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
    event = emit(conn_with([{"x-client-source", "evil-client"}]))
    assert event["client_source"] == "api"
  end

  test "absent source falls back to api" do
    event = emit(conn_with([]))
    assert event["client_source"] == "api"
  end

  test "valid command passes through" do
    event = emit(conn_with([{"x-client-command", "critical-path"}]))
    assert event["client_command"] == "critical-path"
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

  test "client_trace extracted from valid traceparent" do
    conn =
      conn_with([
        {"traceparent", "00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01"}
      ])

    event = emit(conn)
    assert event["client_trace"] == "0af7651916cd43dd8448eb211c80319c"
  end

  test "client_trace is na when traceparent absent" do
    event = emit(conn_with([]))
    assert event["client_trace"] == "na"
  end

  test "client_trace is na when traceparent malformed" do
    event = emit(conn_with([{"traceparent", "garbage"}]))
    assert event["client_trace"] == "na"
  end

  test "client_trace is na when trace-id contains non-hex" do
    non_hex = "00-zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz-b7ad6b7169203331-01"
    event = emit(conn_with([{"traceparent", non_hex}]))
    assert event["client_trace"] == "na"
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

  test "trace_id/1 returns nil when absent" do
    assert ClientMetrics.trace_id(conn_with([])) == nil
  end

  test "trace_id/1 returns the 32-hex segment from a valid traceparent" do
    conn = conn_with([{"traceparent", "00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01"}])
    assert ClientMetrics.trace_id(conn) == "0af7651916cd43dd8448eb211c80319c"
  end
end
