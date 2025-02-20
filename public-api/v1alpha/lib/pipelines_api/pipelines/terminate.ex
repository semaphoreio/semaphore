defmodule PipelinesAPI.Pipelines.Terminate do
  @moduledoc false

  alias PipelinesAPI.PipelinesClient
  alias PipelinesAPI.Util.Metrics
  alias PipelinesAPI.Pipelines.Common
  use Plug.Builder

  import PipelinesAPI.Pipelines.Authorize, only: [authorize_update: 2]

  plug(:authorize_update)
  plug(:terminate)

  def terminate(conn, _opts) do
    Metrics.benchmark("PipelinesAPI.router", ["terminate"], fn ->
      case Map.get(conn.params, "terminate_request") do
        true -> conn.params["pipeline_id"] |> PipelinesClient.terminate()
        _ -> {:error, {:user, "Value of 'terminate_request' field must be boolean value 'true'."}}
      end
      |> Common.respond(conn)
    end)
  end
end
