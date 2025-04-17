defmodule PublicAPI.Handlers.Canvases.Loader do
  @moduledoc """
  Loader for canvases.
  """
  @behaviour Plug

  alias InternalClients.Canvases, as: CanvasesClient
  import PublicAPI.Util.PlugContextHelper

  @impl true
  def init(_opts), do: []

  @impl true
  def call(conn, _opts) do
    org_id = conn.assigns[:organization_id]
    {id, name} = get_id_and_name(conn.params.id_or_name)

    %{id: id, name: name, organization_id: org_id}
    |> CanvasesClient.describe_canvas()
    |> set_resource(conn)
  end
end
