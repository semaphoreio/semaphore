defmodule PipelinesAPI.Workflows.Reschedule do
  @moduledoc false

  require Logger
  alias PipelinesAPI.Audit
  alias PipelinesAPI.Pipelines.Common
  alias PipelinesAPI.Util.Map, as: MapUtil
  alias PipelinesAPI.Util.Metrics
  alias PipelinesAPI.Util.ToTuple
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

      case log_workflow_rebuild(conn) do
        {:ok, _audit} ->
          WorkflowClient.reschedule(
            conn.params["wf_id"],
            requester_id,
            conn.params["request_token"]
          )
          |> Common.respond(conn)

        {:error, reason} ->
          Metrics.increment("PipelinesAPI.router", ["wf_reschedule_audit_failed"])
          Logger.error("Failed to audit workflow reschedule request: #{inspect(reason)}")
          Common.respond(ToTuple.internal_error("Internal error"), conn)
      end
    end)
  end

  defp log_workflow_rebuild(conn) do
    Audit.log_workflow_rebuild(conn, workflow_audit_payload(conn))
  end

  defp workflow_audit_payload(conn) do
    workflow = conn.assigns[:audit_workflow] || %{}
    project_id = MapUtil.get(workflow, "project_id", conn.params["project_id"] || "")

    %{
      "wf_id" => MapUtil.get(workflow, "wf_id", conn.params["wf_id"] || ""),
      "project_id" => project_id,
      "branch_name" => MapUtil.get(workflow, "branch_name", ""),
      "commit_sha" => MapUtil.get(workflow, "commit_sha", "")
    }
  end
end
