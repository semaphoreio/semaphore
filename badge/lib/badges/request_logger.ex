defmodule Badges.RequestLogger do
  import Plug.Conn
  require Logger

  def init(options), do: options

  def call(conn, _opts) do
    start = System.monotonic_time()

    register_before_send(conn, fn conn ->
      stop = System.monotonic_time()

      time_us = System.convert_time_unit(stop - start, :native, :microsecond)
      time_ms = div(time_us, 100) / 10

      Logger.info(fn ->
        "#{conn.method} #{conn.request_path} #{conn.status} #{time_ms}ms"
      end)

      conn
    end)
  end
end
