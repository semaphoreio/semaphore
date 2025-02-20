defmodule PublicAPI.Handlers.Tasks.Loader do
  @moduledoc """
  Loader for tasks, loads the task and sets the resource in the connection.
  """
  @behaviour Plug

  alias InternalClients.Schedulers, as: Client
  import PublicAPI.Util.PlugContextHelper

  @impl true
  def init(_opts), do: []

  @impl true
  def call(conn, _opts) do
    conn.params
    |> Client.describe()
    |> set_response(conn)
  end
end
