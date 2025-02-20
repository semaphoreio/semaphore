defmodule PipelinesAPI.SelfHostedAgentTypes.Create do
  @moduledoc """
  Plug which serves for creating a self-hosted agent type
  """

  use Plug.Builder

  alias PipelinesAPI.Pipelines.Common, as: RespCommon
  alias PipelinesAPI.Util.Metrics
  alias PipelinesAPI.SelfHostedHubClient

  import PipelinesAPI.SelfHostedAgentTypes.Authorize, only: [authorize_manage: 2]

  plug(:authorize_manage)
  plug(:create_sh_agent_type)

  def create_sh_agent_type(conn, _opts) do
    Metrics.benchmark("PipelinesAPI.router", ["sh_agent_type_create"], fn ->
      conn.params
      |> SelfHostedHubClient.create(conn)
      |> RespCommon.respond(conn)
    end)
  end
end
