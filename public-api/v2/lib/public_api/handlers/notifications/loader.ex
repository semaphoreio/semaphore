defmodule PublicAPI.Handlers.Notifications.Loader do
  @moduledoc """
  Loader for notifications, loads the project and sets the resource in the connection.
  """
  @behaviour Plug

  alias InternalClients.Notifications, as: NotificationsClient
  import PublicAPI.Util.PlugContextHelper

  @impl true
  def init(_opts), do: []

  @impl true
  def call(conn, _opts) do
    org_id = conn.assigns[:organization_id]
    user_id = conn.assigns[:user_id]

    {id, name} = get_id_and_name(conn.params.id_or_name)

    %{id: id, name: name, organization_id: org_id, user_id: user_id}
    |> NotificationsClient.describe()
    |> set_response(conn)
  end
end
