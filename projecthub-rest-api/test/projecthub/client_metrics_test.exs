defmodule Projecthub.ClientMetricsTest do
  use ExUnit.Case

  alias Projecthub.ClientMetrics
  alias Plug.Test

  defp conn_with(headers) do
    Enum.reduce(headers, Test.conn(:get, "/api/v1alpha/projects"), fn {k, v}, conn ->
      Plug.Conn.put_req_header(conn, k, v)
    end)
  end

  test "builds graphite-safe [source, command, version] from headers" do
    conn =
      conn_with([
        {"x-client-source", "semai-cli"},
        {"x-client-command", "project_list"},
        {"x-client-version", "1.4.0"}
      ])

    assert ClientMetrics.client_tags(conn) == ["semai-cli", "project_list", "1_4_0"]
  end

  test "header-less traffic defaults to source=api with na dimensions" do
    assert ClientMetrics.client_tags(conn_with([])) == ["api", "na", "na"]
  end

  test "rejects an unknown source value, falling back to api" do
    assert ClientMetrics.source(conn_with([{"x-client-source", "evil"}])) == "api"
  end

  test "encodes status in the metric name suffix" do
    assert ClientMetrics.metric_name(200) == "Projecthub.router.client_request.ok"
    assert ClientMetrics.metric_name(404) == "Projecthub.router.client_request.client_error"
    assert ClientMetrics.metric_name(503) == "Projecthub.router.client_request.server_error"
  end

  test "org from auth-set headers: username preferred, id fallback, nil when absent" do
    assert ClientMetrics.org_tag(conn_with([{"x-semaphore-org-username", "acme"}])) == "acme"

    assert ClientMetrics.org_tag(
             conn_with([{"x-semaphore-org-id", "1bdc0370-a347-4cd6-8a01-1228ae6c6c83"}])
           ) == "1bdc0370-a347-4cd6-8a01-1228ae6c6c83"

    assert ClientMetrics.org_tag(conn_with([])) == nil
  end
end
