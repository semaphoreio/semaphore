defmodule PipelinesAPI.SelfHostedAgentTypes.Describe do
  @moduledoc """
  Plug which serves for escribing a self-hosted agent type
  """

  use Plug.Builder

  alias PipelinesAPI.Pipelines.Common, as: RespCommon
  alias PipelinesAPI.Util.Metrics
  alias PipelinesAPI.SelfHostedHubClient

  import PipelinesAPI.SelfHostedAgentTypes.Authorize, only: [authorize_view: 2]

  plug(:authorize_view)
  plug(:describe_sh_agent_type)

  def describe_sh_agent_type(conn, _opts) do
    Metrics.benchmark("PipelinesAPI.router", ["sh_agent_type_describe"], fn ->
      conn.params
      |> SelfHostedHubClient.describe(conn)
      |> RespCommon.respond(conn)
    end)
  end
end
