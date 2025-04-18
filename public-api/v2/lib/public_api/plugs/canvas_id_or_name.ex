defmodule PublicAPI.Plugs.CanvasIdOrName do
  @behaviour Plug
  @moduledoc """
  Plug to cast canvas_id_or_name to canvas_id or canvas_name
  Used for projects and it's nested resources
  """

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts) do
    id_or_name = conn.params.canvas_id_or_name

    params =
      case UUID.info(id_or_name) do
        {:ok, _info} ->
          Map.put(conn.params, :canvas_id, id_or_name)

        {:error, _} ->
          Map.put(conn.params, :canvas_name, id_or_name)
      end

    Map.put(conn, :params, params)
  end
end
