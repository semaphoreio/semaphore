defmodule PipelinesAPI.Pipelines.PartialRebuild do
  @moduledoc false

  alias PipelinesAPI.PipelinesClient
  alias PipelinesAPI.Util.Metrics
  alias PipelinesAPI.Pipelines.Common
  alias Plug.Conn

  use Plug.Builder

  import PipelinesAPI.Pipelines.Authorize, only: [authorize_create: 2]

  plug(:authorize_create)
  plug(:partial_rebuild)

  def partial_rebuild(conn, _opts) do
    Metrics.benchmark("PipelinesAPI", ["partial_rebuild"], fn ->
      PipelinesClient.partial_rebuild(
        conn.params["pipeline_id"],
        conn.params["request_token"],
        Conn.get_req_header(conn, "x-semaphore-user-id") |> Enum.at(0, "")
      )
      |> Common.respond(conn)
    end)
  end
end
