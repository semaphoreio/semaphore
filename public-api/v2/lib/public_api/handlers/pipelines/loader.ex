defmodule PublicAPI.Handlers.Pipelines.Loader do
  @moduledoc """
  Loader for pipelines, loads the project and sets the resource in the connection.
  """
  @behaviour Plug

  alias InternalClients.Pipelines, as: PipelinesClient
  import PublicAPI.Util.PlugContextHelper

  @impl true
  def init(_opts), do: []

  @impl true
  def call(conn, _opts) do
    conn.params
    |> PipelinesClient.describe()
    |> set_response(conn)
  end
end
