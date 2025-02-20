defmodule PublicAPI.Plugs.ProjectIdOrName do
  @behaviour Plug
  @moduledoc """
  Plug to cast project_id_or_name to project_id or project_name
  Used for projects and it's nested resources
  """

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts) do
    id_or_name = conn.params.project_id_or_name

    params =
      case UUID.info(id_or_name) do
        {:ok, _info} ->
          Map.put(conn.params, :project_id, id_or_name)

        {:error, _} ->
          Map.put(conn.params, :project_name, id_or_name)
      end

    Map.put(conn, :params, params)
  end
end
