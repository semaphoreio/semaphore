defmodule FrontWeb.Plugs.OnPremBlocker do
  @moduledoc """
    This plug is blocking access when on-premise is enabled.

    If on-premise, 404 response is returned.
  """
  require Logger

  def init(default), do: default

  def call(conn, _opts) do
    if Front.saas?() do
      conn
    else
      Logger.info("Blocking access to #{conn.request_path} because of on-premises")

      conn
      |> FrontWeb.PageController.status404(%{})
      |> Plug.Conn.halt()
    end
  end
end
