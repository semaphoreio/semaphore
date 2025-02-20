defmodule PublicAPI.Plugs.ContentType do
  @moduledoc """
    Plug for setting content type header.
  """

  import Plug.Conn

  def init(value), do: value
  def call(conn, value), do: put_resp_header(conn, "content-type", value)
end
