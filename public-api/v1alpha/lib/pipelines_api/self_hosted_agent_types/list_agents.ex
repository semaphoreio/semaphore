defmodule PipelinesAPI.SelfHostedAgentTypes.ListAgents do
  @moduledoc """
  Plug which serves for listing self-hosted agents
  """

  use Plug.Builder

  alias PipelinesAPI.Pipelines.Common, as: RespCommon
  alias PipelinesAPI.Util.Metrics
  alias PipelinesAPI.SelfHostedHubClient

  import PipelinesAPI.SelfHostedAgentTypes.Authorize, only: [authorize_view: 2]

  plug(:authorize_view)
  plug(:list_sh_agents)

  def list_sh_agents(conn, _opts) do
    Metrics.benchmark("PipelinesAPI.router", ["sh_agent_list"], fn ->
      conn.params
      |> SelfHostedHubClient.list_agents(conn)
      |> RespCommon.respond(conn)
    end)
  end
end
