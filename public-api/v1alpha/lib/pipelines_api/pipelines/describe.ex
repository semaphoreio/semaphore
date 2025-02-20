defmodule PipelinesAPI.Pipelines.Describe do
  @moduledoc false

  alias PipelinesAPI.PipelinesClient
  alias PipelinesAPI.Util.Metrics
  alias PipelinesAPI.Pipelines.Common
  use Plug.Builder

  import PipelinesAPI.Pipelines.Authorize, only: [authorize_read: 2]

  plug(:authorize_read)
  plug(:describe)

  def describe(conn, _opts) do
    Metrics.benchmark("PipelinesAPI.router", ["describe"], fn ->
      conn.params["pipeline_id"]
      |> PipelinesClient.describe(conn.params)
      |> Common.respond(conn)
    end)
  end
end
