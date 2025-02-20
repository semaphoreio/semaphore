# credo:disable-for-this-file Credo.Check.Design.DuplicatedCode

defmodule PipelinesAPI.Troubleshoot.Pipeline do
  @moduledoc """
  Plug which serves for gathering troubleshoot information for a pritcular pipeline.
  """

  use Plug.Builder

  alias PipelinesAPI.Pipelines.Common, as: RespCommon
  alias PipelinesAPI.Util.{Metrics, ToTuple}
  alias PipelinesAPI.{WorkflowClient, PipelinesClient}
  alias LogTee, as: LT

  import PipelinesAPI.Pipelines.Authorize, only: [authorize_read: 2]

  plug(:authorize_read)
  plug(:troubleshoot_data)

  def troubleshoot_data(conn, _opts) do
    Metrics.benchmark("PipelinesAPI.router", ["troubleshoot_pipeline"], fn ->
      conn.params
      |> collect_information()
      |> format_response()
      |> RespCommon.respond(conn)
    end)
  end

  defp collect_information(%{"pipeline_id" => ppl_id}) do
    with {:ok, response} <- PipelinesClient.describe(ppl_id, %{"detailed" => "true"}),
         %{pipeline: pipeline, blocks: blocks} <- response,
         {:ok, %{workflow: workflow}} <- WorkflowClient.describe(pipeline.wf_id, true) do
      %{workflow: workflow, pipeline: pipeline, blocks: blocks} |> ToTuple.ok()
    else
      error ->
        LT.error(error, "Error while collecting information for pipeline troubleshoot")
        ToTuple.internal_error("Internal error")
    end
  end

  defp format_response({:ok, resources}) do
    %{workflow: wf, pipeline: ppl, blocks: blocks} = resources
    blocks = Enum.map(blocks, fn block -> format_block(block) end)

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
      },
      pipeline: %{
        ppl_id: ppl.ppl_id,
        name: ppl.name,
        created_at: ppl.created_at,
        pending_at: ppl.pending_at,
        queuing_at: ppl.queuing_at,
        running_at: ppl.running_at,
        stopping_at: ppl.stopping_at,
        done_at: ppl.done_at,
        state: ppl.state,
        result: Map.get(ppl, :result, ""),
        result_reason: Map.get(ppl, :result_reason, ""),
        terminate_request: ppl.terminate_request,
        error_description: ppl.error_description,
        switch_id: ppl.switch_id,
        working_directory: ppl.working_directory,
        yaml_file_name: ppl.yaml_file_name,
        terminated_by: ppl.terminated_by,
        queue_id: ppl.queue.queue_id,
        queue_name: ppl.queue.name,
        queue_scope: ppl.queue.scope,
        queue_type: ppl.queue.type,
        promotion_of: ppl.promotion_of,
        partial_rerun_of: ppl.partial_rerun_of,
        partially_rerun_by: ppl.partially_rerun_by,
        blocks: blocks
      }
    }
    |> ToTuple.ok()
  end

  defp format_response(error = {:error, _}), do: error

  defp format_block(block) do
    %{
      block_id: block.block_id,
      name: block.name,
      build_req_id: block.build_req_id,
      state: block.state,
      result: Map.get(block, :result, ""),
      result_reason: Map.get(block, :result_reason, ""),
      error_description: block.error_description
    }
  end
end
