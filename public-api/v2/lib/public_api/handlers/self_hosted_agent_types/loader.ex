defmodule PublicAPI.Handlers.SelfHostedAgentTypes.Loader do
  @moduledoc """
  Loader for self hosted agent types, loads the resource and sets the resource in the connection.
  """
  @behaviour Plug

  alias InternalClients.SelfHostedHub, as: SelfHostedHubClient
  import PublicAPI.Util.PlugContextHelper

  @impl true
  def init(_opts), do: []

  @impl true
  def call(conn, _opts) do
    org_id = conn.assigns[:organization_id]
    user_id = conn.assigns[:user_id]

    conn.params
    |> Map.merge(%{organization_id: org_id, requester_id: user_id})
    |> SelfHostedHubClient.describe()
    |> set_response(conn)
  end
end
