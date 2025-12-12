defmodule FrontWeb.Plugs.ConditionalETag do
  @moduledoc """
  A wrapper around ETag.Plug that skip ETag generation for chunked responses.
  """

  import Plug.Conn, only: [register_before_send: 2]

  def init(opts), do: ETag.Plug.init(opts)

  def call(conn, opts) do
    register_before_send(conn, fn conn ->
      # Skip ETag generation for chunked responses
      if conn.state == :chunked do
        conn
      else
        ETag.Plug.handle_etag(conn, opts)
      end
    end)
  end
end
