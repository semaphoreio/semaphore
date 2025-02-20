defmodule PublicAPI.Handlers.Dashboards.Loader do
  @moduledoc """
  Loader for dashboards, loads the project and sets the resource in the connection.
  """
  @behaviour Plug

  alias InternalClients.Dashboards, as: DashboardsClient
  import PublicAPI.Util.PlugContextHelper

  @impl true
  def init(_opts), do: []

  @impl true
  def call(conn, _opts) do
    org_id = conn.assigns[:organization_id]
    user_id = conn.assigns[:user_id]

    %{id_or_name: conn.params.id_or_name, organization_id: org_id, user_id: user_id}
    |> DashboardsClient.describe()
    |> set_resource(conn)
  end
end
