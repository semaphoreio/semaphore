defmodule PipelinesAPI.SelfHostedAgentTypes.List do
  @moduledoc """
  Plug which serves for listing a self-hosted agent types
  """

  use Plug.Builder

  alias PipelinesAPI.Pipelines.Common, as: RespCommon
  alias PipelinesAPI.Util.Metrics
  alias PipelinesAPI.SelfHostedHubClient

  import PipelinesAPI.SelfHostedAgentTypes.Authorize, only: [authorize_view: 2]

  plug(:authorize_view)
  plug(:list_sh_agent_types)

  def list_sh_agent_types(conn, _opts) do
    Metrics.benchmark("PipelinesAPI.router", ["sh_agent_type_list"], fn ->
      conn.params
      |> SelfHostedHubClient.list(conn)
      |> RespCommon.respond(conn)
    end)
  end
end
