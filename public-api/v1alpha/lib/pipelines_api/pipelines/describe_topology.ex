defmodule PipelinesAPI.Pipelines.DescribeTopology do
  @moduledoc false

  alias PipelinesAPI.PipelinesClient
  alias PipelinesAPI.Util.Metrics
  alias PipelinesAPI.Pipelines.Common
  use Plug.Builder

  import PipelinesAPI.Pipelines.Authorize, only: [authorize_read: 2]

  plug(:authorize_read)
  plug(:describe_topology)

  def describe_topology(conn, _opts) do
    Metrics.benchmark("PipelinesAPI", ["describe_topology"], fn ->
      PipelinesClient.describe_topology(conn.params["pipeline_id"])
      |> Common.respond(conn)
    end)
  end
end
