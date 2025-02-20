defmodule PipelinesAPI.Workflows.Reschedule do
  @moduledoc false

  alias PipelinesAPI.Util.Metrics
  alias PipelinesAPI.Pipelines.Common
  alias PipelinesAPI.WorkflowClient
  alias Plug.Conn

  use Plug.Builder

  import PipelinesAPI.Workflows.WfAuthorize, only: [wf_authorize_create: 2]
  import PipelinesAPI.Workflows.WfAuthorize.AuthorizeParams, only: [get_initial_ppl_id: 2]

  plug(:get_initial_ppl_id)
  plug(:wf_authorize_create)
  plug(:reschedule)

  def reschedule(conn, _opts) do
    Metrics.benchmark("PipelinesAPI.router", ["wf_reschedule"], fn ->
      requester_id = Conn.get_req_header(conn, "x-semaphore-user-id") |> Enum.at(0, "")

      WorkflowClient.reschedule(conn.params["wf_id"], requester_id, conn.params["request_token"])
      |> Common.respond(conn)
    end)
  end
end
