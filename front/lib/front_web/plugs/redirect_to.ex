defmodule FrontWeb.Plugs.RedirectTo do
  import Plug.Conn

  def init(default), do: default

  def call(conn, opts) do
    conn
    |> Phoenix.Controller.redirect(to: opts[:to])
    |> halt()
  end
end
