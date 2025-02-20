defmodule PipelinesAPI.SelfHostedAgentTypes.DescribeAgent do
  @moduledoc """
  Plug which serves for describing a self-hosted agent
  """

  use Plug.Builder

  alias PipelinesAPI.Pipelines.Common, as: RespCommon
  alias PipelinesAPI.Util.Metrics
  alias PipelinesAPI.SelfHostedHubClient

  import PipelinesAPI.SelfHostedAgentTypes.Authorize, only: [authorize_view: 2]

  plug(:authorize_view)
  plug(:describe_sh_agent)

  def describe_sh_agent(conn, _opts) do
    Metrics.benchmark("PipelinesAPI.router", ["sh_agent_describe"], fn ->
      conn.params
      |> SelfHostedHubClient.describe_agent(conn)
      |> RespCommon.respond(conn)
    end)
  end
end
