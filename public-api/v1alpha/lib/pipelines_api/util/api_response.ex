defmodule PipelinesAPI.Util.APIResponse do
  import Plug.Conn

  @doc """
  Sends JSON response.


      iex> json(conn, %{id: 123})

  """
  @spec json(Plug.Conn.t(), term) :: Plug.Conn.t()
  def json(conn, data) do
    content = Poison.encode!(data)
    send_resp(conn, conn.status || 200, "application/json", content)
  end

  @doc """
  Sends text response.

  ## Examples

      iex> text(conn, "hello")

      iex> text(conn, :implements_to_string)

  """
  @spec text(Plug.Conn.t(), String.Chars.t()) :: Plug.Conn.t()
  def text(conn, data) do
    send_resp(conn, conn.status || 200, "text/plain", to_string(data))
  end
end
