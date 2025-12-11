defmodule FrontWeb.Plugs.ConditionalETag do
  @moduledoc """
  A wrapper around ETag.Plug that skips ETag generation when the response body is nil.

  This prevents crashes when trying to generate ETags for chunked responses or other
  cases where the response body is not available in the before_send callback.
  """

  import Plug.Conn, only: [register_before_send: 2]

  def init(opts), do: ETag.Plug.init(opts)

  def call(conn, opts) do
    register_before_send(conn, fn conn ->
      # Skip ETag generation when there's no response body
      if is_nil(conn.resp_body) do
        conn
      else
        ETag.Plug.handle_etag(conn, opts)
      end
    end)
  end
end
