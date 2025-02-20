# credo:disable-for-this-file Credo.Check.Design.DuplicatedCode

defmodule PipelinesAPI.Troubleshoot.Workflow do
  @moduledoc """
  Plug which serves for gathering troubleshoot information for a pritcular workflow.
  """

  use Plug.Builder

  alias PipelinesAPI.Pipelines.Common, as: RespCommon
  alias PipelinesAPI.Util.{Metrics, ToTuple}
  alias PipelinesAPI.{WorkflowClient}
  alias LogTee, as: LT

  import PipelinesAPI.Workflows.WfAuthorize, only: [wf_authorize_read: 2]
  import PipelinesAPI.Workflows.WfAuthorize.AuthorizeParams, only: [get_initial_ppl_id: 2]

  plug(:get_initial_ppl_id)
  plug(:wf_authorize_read)
  plug(:troubleshoot_data)

  def troubleshoot_data(conn, _opts) do
    Metrics.benchmark("PipelinesAPI.router", ["troubleshoot_pipeline"], fn ->
      conn.params
      |> collect_information()
      |> format_response()
      |> RespCommon.respond(conn)
    end)
  end

  defp collect_information(%{"wf_id" => wf_id}) do
    case WorkflowClient.describe(wf_id, true) do
      resp = {:ok, _workflow} ->
        resp

      error ->
        LT.error(error, "Error while collecting information for workflow troubleshoot")
        ToTuple.internal_error("Internal error")
    end
  end

  defp format_response({:ok, %{workflow: wf}}) do
    %{
      project: %{
        id: wf.project_id,
        organization_id: wf.organization_id
      },
      workflow: %{
        wf_id: wf.wf_id,
        initial_ppl_id: wf.initial_ppl_id,
        hook_id: wf.hook_id,
        requester_id: wf.requester_id,
        branch_id: wf.branch_id,
        branch_name: wf.branch_name,
        commit_sha: wf.commit_sha,
        created_at: wf.created_at,
        triggered_by: wf.triggered_by,
        rerun_of: wf.rerun_of,
        repository_id: wf.repository_id
      }
    }
    |> ToTuple.ok()
  end

  defp format_response(error = {:error, _}), do: error
end
