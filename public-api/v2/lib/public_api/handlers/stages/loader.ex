defmodule PublicAPI.Handlers.Stages.Loader do
  @moduledoc """
  Loader for stages.
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

    %{
      id: id,
      name: name,
      organization_id: org_id,
      canvas_id: conn.params.canvas_id
    }
    |> CanvasesClient.describe_stage()
    |> set_resource(conn)
  end
end
