defmodule FrontWeb.CiAssistantView do
  use FrontWeb, :view

  def json_config(conn) do
    token =
      Phoenix.Token.sign(
        FrontWeb.Endpoint,
        "ci_assistant",
        %{user_id: conn.assigns.user_id, org_id: conn.assigns.organization_id}
      )

    %{socketToken: token}
    |> Poison.encode!()
  end
end
