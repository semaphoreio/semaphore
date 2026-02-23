defmodule FrontWeb.CiAssistantView do
  use FrontWeb, :view

  def json_config(conn) do
    token =
      Front.CiAssistant.Token.mint(conn.assigns.user_id, conn.assigns.organization_id)

    gateway_ws_url =
      case Application.get_env(:front, :ci_assistant_gateway_ws_url) do
        url when url in [nil, ""] -> "wss://#{conn.host}/ws"
        url -> url
      end

    %{
      gatewayWsUrl: gateway_ws_url,
      hmacToken: token
    }
    |> Poison.encode!()
  end
end
