defmodule PipelinesAPI.SelfHostedAgentTypes.DisableAll do
  @moduledoc """
  Plug which serves for disable (idle or all) agents for a self-hosted agent type
  """

  use Plug.Builder

  alias PipelinesAPI.Pipelines.Common, as: RespCommon
  alias PipelinesAPI.Util.Metrics
  alias PipelinesAPI.SelfHostedHubClient

  import PipelinesAPI.SelfHostedAgentTypes.Authorize, only: [authorize_manage: 2]

  plug(:authorize_manage)
  plug(:disable_all_agents)

  def disable_all_agents(conn, _opts) do
    Metrics.benchmark("PipelinesAPI.router", ["sh_agent_type_disable_all"], fn ->
      conn.params
      |> SelfHostedHubClient.disable_all(conn)
      |> RespCommon.respond(conn)
    end)
  end
end
