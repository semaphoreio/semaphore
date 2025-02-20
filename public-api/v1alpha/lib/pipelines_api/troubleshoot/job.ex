defmodule PipelinesAPI.Troubleshoot.Job do
  @moduledoc """
  Plug which serves for gathering troubleshoot information for a pritcular job.
  """

  use Plug.Builder

  alias PipelinesAPI.Pipelines.Common, as: RespCommon
  alias PipelinesAPI.Util.{Metrics, ToTuple}
  alias PipelinesAPI.{WorkflowClient, PipelinesClient, JobsClient}
  alias LogTee, as: LT

  import PipelinesAPI.Troubleshoot.Authorize, only: [authorize_job: 2]

  plug(:describe_job)
  plug(:authorize_job)
  plug(:prepare_response)

  def describe_job(conn, _opts) do
    Metrics.benchmark("PipelinesAPI.router", ["describe_job"], fn ->
      conn.params
      |> JobsClient.describe()
      |> continue_or_halt(conn)
    end)
  end

  def continue_or_halt({:ok, job}, conn) do
    params = Map.merge(conn.params, %{job: job})
    conn |> Map.put(:params, params)
  end

  def continue_or_halt(error, conn) do
    RespCommon.respond(error, conn) |> halt
  end

  def prepare_response(conn, _opts) do
    Metrics.benchmark("PipelinesAPI.router", ["troubleshoot_job"], fn ->
      conn.params
      |> collect_information()
      |> format_response()
      |> RespCommon.respond(conn)
    end)
  end

  defp collect_information(resources = %{job: %{ppl_id: ppl_id}}) do
    with {:ok, response} <- PipelinesClient.describe(ppl_id, %{"detailed" => "true"}),
         %{pipeline: pipeline, blocks: blocks} <- response,
         {:ok, %{workflow: workflow}} <- WorkflowClient.describe(pipeline.wf_id, true),
         find_block_func <- fn block -> block.build_req_id == resources.job.build_req_id end,
         block <- Enum.find(blocks, find_block_func) do
      resources
      |> Map.merge(%{workflow: workflow, pipeline: pipeline, block: block})
      |> ToTuple.ok()
    else
      error ->
        LT.error(error, "Error while collecting information for job troubleshoot")
        ToTuple.internal_error("Internal error")
    end
  end

  defp format_response({:ok, resources}) do
    %{workflow: wf, pipeline: ppl, block: block, job: job} = resources

    %{
      project: %{
        id: job.project_id,
        organization_id: job.organization_id
      },
      workflow: %{
        wf_id: wf.wf_id,
        initial_ppl_id: wf.initial_ppl_id,
        project_id: wf.project_id,
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
        partially_rerun_by: ppl.partially_rerun_by
      },
      block: %{
        block_id: block.block_id,
        name: block.name,
        build_req_id: block.build_req_id,
        state: block.state,
        result: Map.get(block, :result, ""),
        result_reason: Map.get(block, :result_reason, ""),
        error_description: block.error_description
      },
      job: %{
        id: job.id,
        build_req_id: job.build_req_id,
        name: job.name,
        state: job.state,
        failure_reason: job.failure_reason,
        is_debug_job: job.is_debug_job,
        is_self_hosted: job.self_hosted,
        machine_type: job.machine_type,
        os_image: job.machine_os_image,
        agent_name: job.agent_name,
        created_at: job.timeline.created_at,
        enqueued_at: job.timeline.enqueued_at,
        started_at: job.timeline.started_at,
        finished_at: job.timeline.finished_at,
        priority: job.priority
      }
    }
    |> ToTuple.ok()
  end

  defp format_response(error = {:error, _}), do: error
end
