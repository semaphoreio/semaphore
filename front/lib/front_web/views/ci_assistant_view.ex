defmodule FrontWeb.CiAssistantView do
  use FrontWeb, :view

  def json_config(conn) do
    hmac_token = Front.CiAssistant.Token.mint(conn.assigns.user_id, conn.assigns.organization_id)

    %{hmacToken: hmac_token}
    |> Poison.encode!()
  end
end
