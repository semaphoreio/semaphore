defmodule PipelinesAPI.Workflows.Terminate do
  @moduledoc false

  alias PipelinesAPI.WorkflowClient
  alias PipelinesAPI.Util.Metrics
  alias PipelinesAPI.Pipelines.Common
  use Plug.Builder
  alias Plug.Conn

  import PipelinesAPI.Workflows.WfAuthorize, only: [wf_authorize_update: 2]
  import PipelinesAPI.Workflows.WfAuthorize.AuthorizeParams, only: [get_initial_ppl_id: 2]

  plug(:get_initial_ppl_id)
  plug(:wf_authorize_update)
  plug(:terminate)

  def terminate(conn, _opts) do
    Metrics.benchmark("PipelinesAPI.router", ["terminate"], fn ->
      case Map.fetch(conn.params, "wf_id") do
        {:ok, wf_id} ->
          requester_id = Conn.get_req_header(conn, "x-semaphore-user-id") |> Enum.at(0, "")
          WorkflowClient.terminate(wf_id, requester_id)

        _ ->
          {:error, {:user, "wf_id is missing"}}
      end
      |> Common.respond(conn)
    end)
  end
end
