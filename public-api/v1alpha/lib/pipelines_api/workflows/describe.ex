defmodule PipelinesAPI.Workflows.Describe do
  @moduledoc false

  alias PipelinesAPI.Util.Metrics
  alias PipelinesAPI.Pipelines.Common
  use Plug.Builder
  alias PipelinesAPI.WorkflowClient

  import PipelinesAPI.Workflows.WfAuthorize, only: [wf_authorize_read: 2]
  import PipelinesAPI.Workflows.WfAuthorize.AuthorizeParams, only: [get_initial_ppl_id: 2]

  plug(:get_initial_ppl_id)
  plug(:wf_authorize_read)
  plug(:describe)

  def describe(conn, _opts) do
    Metrics.benchmark("PipelinesAPI.router", ["wf_describe"], fn ->
      conn.params["wf_id"]
      |> WorkflowClient.describe()
      |> Common.respond(conn)
    end)
  end
end
