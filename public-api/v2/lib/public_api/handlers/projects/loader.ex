defmodule PublicAPI.Handlers.Projects.Loader do
  @moduledoc """
  Loader for projects handlers, loads the project and sets the resource in the connection.
  """
  @behaviour Plug

  alias InternalClients.Projecthub, as: ProjectsClient
  import PublicAPI.Util.PlugContextHelper

  @impl true
  def init(_opts), do: []

  @impl true
  def call(conn, _opts) do
    org_id = conn.assigns[:organization_id]
    user_id = conn.assigns[:user_id]

    conn.params
    |> Map.merge(%{
      organization_id: org_id,
      user_id: user_id,
      id: conn.assigns[:project_id],
      name: conn.assigns[:project_name]
    })
    |> ProjectsClient.describe()
    |> set_response(conn)
  end
end
