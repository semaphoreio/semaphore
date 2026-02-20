defmodule FrontWeb.CiAssistantSocket do
  use Phoenix.Socket

  channel "ci_assistant:*", FrontWeb.CiAssistantChannel

  @impl true
  def connect(%{"token" => token}, socket, _connect_info) do
    case Phoenix.Token.verify(FrontWeb.Endpoint, "ci_assistant", token, max_age: 86_400) do
      {:ok, %{user_id: user_id, org_id: org_id}} ->
        {:ok, assign(socket, user_id: user_id, org_id: org_id)}

      {:error, _} ->
        :error
    end
  end

  def connect(_params, _socket, _connect_info), do: :error

  @impl true
  def id(socket), do: "ci_assistant:#{socket.assigns.user_id}"
end
