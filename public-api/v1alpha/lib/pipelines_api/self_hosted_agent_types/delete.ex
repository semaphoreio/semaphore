defmodule PipelinesAPI.SelfHostedAgentTypes.Delete do
  @moduledoc """
  Plug which serves for deleting self-hosted agent types
  """

  use Plug.Builder

  alias PipelinesAPI.Pipelines.Common, as: RespCommon
  alias PipelinesAPI.Util.Metrics
  alias PipelinesAPI.SelfHostedHubClient

  import PipelinesAPI.SelfHostedAgentTypes.Authorize, only: [authorize_manage: 2]

  plug(:authorize_manage)
  plug(:delete_sh_agent_type)

  def delete_sh_agent_type(conn, _opts) do
    Metrics.benchmark("PipelinesAPI.router", ["sh_agent_type_delete"], fn ->
      conn.params
      |> SelfHostedHubClient.delete(conn)
      |> RespCommon.respond(conn)
    end)
  end
end
