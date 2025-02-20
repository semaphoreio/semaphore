defmodule PipelinesAPI.SelfHostedAgentTypes.Update do
  @moduledoc """
  Plug which serves for updating a self-hosted agent type
  """

  use Plug.Builder

  alias PipelinesAPI.Pipelines.Common, as: RespCommon
  alias PipelinesAPI.Util.Metrics
  alias PipelinesAPI.SelfHostedHubClient

  import PipelinesAPI.SelfHostedAgentTypes.Authorize, only: [authorize_manage: 2]

  plug(:authorize_manage)
  plug(:update_sh_agent_type)

  def update_sh_agent_type(conn, _opts) do
    Metrics.benchmark("PipelinesAPI.router", ["sh_agent_type_update"], fn ->
      conn.params
      |> SelfHostedHubClient.update(conn)
      |> RespCommon.respond(conn)
    end)
  end
end
