defmodule PipelinesAPI.Plug.Logger do
  @moduledoc """
  The basic Plug.Logger does not include the URL query params in the output, and we need that information as well.
  Mostly a copy of https://github.com/elixir-plug/plug/blob/main/lib/plug/logger.ex, but including URL query params.
  """

  require Logger
  alias Plug.Conn
  @behaviour Plug

  @impl true
  def init(opts) do
    Keyword.get(opts, :log, :info)
  end

  @impl true
  def call(conn, level) do
    request_line = [conn.method, ?\s, conn.request_path] ++ query_params(conn.query_string)
    start = System.monotonic_time()

    Conn.register_before_send(conn, fn conn ->
      Logger.log(level, fn ->
        stop = System.monotonic_time()
        diff = System.convert_time_unit(stop - start, :native, :microsecond)
        status = Integer.to_string(conn.status)

        [conn.host, " - "] ++
          [connection_type(conn), ?\s, status, " in ", formatted_diff(diff), " - "] ++
          request_line
      end)

      conn
    end)
  end

  defp query_params(nil), do: []
  defp query_params(""), do: []
  defp query_params(query_params), do: [?\?, query_params]

  defp formatted_diff(diff) when diff > 1000, do: [diff |> div(1000) |> Integer.to_string(), "ms"]
  defp formatted_diff(diff), do: [Integer.to_string(diff), "µs"]

  defp connection_type(%{state: :set_chunked}), do: "Chunked"
  defp connection_type(_), do: "Sent"
end
