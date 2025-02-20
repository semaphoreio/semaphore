defmodule PublicAPI.Handlers.DeploymentTargets.Plugs.Loader do
  @moduledoc """
  Loader for secrets handlers, loads the sercret and sets the resource in the connection.
  """
  @behaviour Plug

  alias InternalClients.DeploymentTargets, as: DTClient
  import PublicAPI.Util.PlugContextHelper

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts) do
    {id, name} = get_id_and_name(conn.params.id_or_name)

    %{
      project_id: conn.assigns[:project_id],
      target_name: name,
      target_id: id
    }
    |> DTClient.describe()
    |> set_response(conn)
  end
end
