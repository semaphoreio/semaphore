defmodule FrontWeb.CiAssistantView do
  use FrontWeb, :view

  def json_config(conn) do
    gateway_ws_url = Application.get_env(:front, :ci_assistant_gateway_ws_url)
    hmac_token = Front.CiAssistant.Token.mint(conn.assigns.user_id, conn.assigns.organization_id)

    %{gatewayWsUrl: gateway_ws_url, hmacToken: hmac_token}
    |> Poison.encode!()
  end
end
