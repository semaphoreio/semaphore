defmodule PipelinesAPI.Util.RequestMetrics do
  @moduledoc false

  alias PipelinesAPI.Util.Metrics
  alias Plug.Conn

  @router_metric "PipelinesAPI.router"

  def track_request(conn, request_tag) when is_binary(request_tag) do
    Conn.register_before_send(conn, fn conn ->
      Metrics.increment(metric_name(request_tag), metric_tags(conn))
      conn
    end)
  end

  def metric_name(request_tag) when is_binary(request_tag), do: "#{@router_metric}.#{request_tag}"

  def metric_tags(conn),
    do: [
      response_status(conn),
      header_tag(conn, "x-semaphore-org-id"),
      header_tag(conn, "x-semaphore-user-id")
    ]

  defp response_status(%Conn{status: status}) when is_integer(status),
    do: Integer.to_string(status)

  defp response_status(_conn), do: "unknown"

  defp header_tag(conn, header_name) do
    conn
    |> Conn.get_req_header(header_name)
    |> List.first()
    |> normalize_tag_value()
  end

  defp normalize_tag_value(value) when is_binary(value) and value != "", do: value
  defp normalize_tag_value(_value), do: "unknown"
end
