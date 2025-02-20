defmodule PublicAPI.Handlers.Workflows.Loader do
  @moduledoc """
  Loader for pipelines, loads the project and sets the resource in the connection.
  """
  @behaviour Plug

  alias InternalClients.Workflow, as: WorkflowClient
  import PublicAPI.Util.PlugContextHelper

  @impl true
  def init(_opts), do: []

  @impl true
  def call(conn, _opts) do
    conn.params.wf_id
    |> WorkflowClient.describe()
    |> set_response(conn)
  end
end
